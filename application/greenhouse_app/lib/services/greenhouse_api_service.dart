import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/api_helpers.dart';
import '../models/auth_session.dart';
import '../models/command.dart';
import '../models/device.dart';
import '../models/measurement.dart';
import '../models/sensor.dart';
import '../models/sensor_reading.dart';
import 'api_exception.dart';

/// Snapshot of a [Device], its [Sensor]s, and its mapped [Measurement]s.
class GreenhouseSnapshot {
  final Device device;
  final List<Sensor> sensors;
  final List<Measurement> measurements;

  /// Creates an immutable [GreenhouseSnapshot].
  const GreenhouseSnapshot({
    required this.device,
    required this.sensors,
    required this.measurements,
  });

  /// Latest combined [SensorReading] across all sensors, or `null` if none exist.
  SensorReading? get latestReading {
    if (measurements.isEmpty) return null;

    final typeBySensorId = <int, GreenhouseSensorType>{};
    for (final sensor in sensors) {
      final normalized = sensor.normalizedType;
      if (normalized != null) {
        typeBySensorId[sensor.id] = normalized;
      }
    }

    final latestByType = <GreenhouseSensorType, Measurement>{};
    for (final measurement in measurements) {
      final sensorId = measurement.sensorId;
      if (sensorId == null) continue;
      final type = typeBySensorId[sensorId];
      if (type == null) continue;
      final current = latestByType[type];
      if (current == null || !measurement.measuredAt.isBefore(current.measuredAt)) {
        latestByType[type] = measurement;
      }
    }

    if (latestByType.isEmpty) return null;

    var latestTimestamp = latestByType.values.first.measuredAt;
    for (final m in latestByType.values.skip(1)) {
      if (m.measuredAt.isAfter(latestTimestamp)) {
        latestTimestamp = m.measuredAt;
      }
    }

    return SensorReading(
      temperature: latestByType[GreenhouseSensorType.temperature]?.value ?? 0.0,
      airHumidity: latestByType[GreenhouseSensorType.airHumidity]?.value ?? 0.0,
      soilMoisture: latestByType[GreenhouseSensorType.soilMoisture]?.value ?? 0.0,
      lightLevel: latestByType[GreenhouseSensorType.lightLevel]?.value ?? 0.0,
      measuredAt: latestTimestamp,
    );
  }

  /// Builds chronological [SensorReading] entries within `[referenceTime - lookback, referenceTime]`.
  List<SensorReading> historyForLookback(
    Duration lookback, {
    DateTime? referenceTime,
  }) {
    final end = (referenceTime ?? DateTime.now()).toUtc();
    final start = end.subtract(lookback);

    final typeBySensorId = <int, GreenhouseSensorType>{};
    for (final sensor in sensors) {
      final normalized = sensor.normalizedType;
      if (normalized != null) {
        typeBySensorId[sensor.id] = normalized;
      }
    }

    final filtered = measurements.where((m) {
      final sensorId = m.sensorId;
      if (sensorId == null || !typeBySensorId.containsKey(sensorId)) {
        return false;
      }
      final utc = m.measuredAt.toUtc();
      return !utc.isBefore(start) && !utc.isAfter(end);
    }).toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

    if (filtered.isEmpty) return const [];

    // Pre-seed each sensor type with its first in-range value so carried
    // points never distort min/max summary calculations with synthetic zeros.
    final seedValues = <GreenhouseSensorType, double>{};
    for (final m in filtered) {
      final type = typeBySensorId[m.sensorId!]!;
      seedValues.putIfAbsent(type, () => m.value);
    }

    final currentValues = <GreenhouseSensorType, double>{
      GreenhouseSensorType.temperature:
          seedValues[GreenhouseSensorType.temperature] ?? 0.0,
      GreenhouseSensorType.airHumidity:
          seedValues[GreenhouseSensorType.airHumidity] ?? 0.0,
      GreenhouseSensorType.soilMoisture:
          seedValues[GreenhouseSensorType.soilMoisture] ?? 0.0,
      GreenhouseSensorType.lightLevel:
          seedValues[GreenhouseSensorType.lightLevel] ?? 0.0,
    };

    // Group measurements recorded at the same timestamp (to the second).
    final buckets = <DateTime, Map<GreenhouseSensorType, double>>{};
    for (final m in filtered) {
      final utc = m.measuredAt.toUtc();
      final bucketKey = DateTime.utc(
        utc.year,
        utc.month,
        utc.day,
        utc.hour,
        utc.minute,
        utc.second,
      );
      final type = typeBySensorId[m.sensorId!]!;
      buckets.putIfAbsent(bucketKey, () => <GreenhouseSensorType, double>{})[type] =
          m.value;
    }

    final sortedTimestamps = buckets.keys.toList()..sort();
    return sortedTimestamps.map((ts) {
      currentValues.addAll(buckets[ts]!);
      return SensorReading(
        temperature: currentValues[GreenhouseSensorType.temperature]!,
        airHumidity: currentValues[GreenhouseSensorType.airHumidity]!,
        soilMoisture: currentValues[GreenhouseSensorType.soilMoisture]!,
        lightLevel: currentValues[GreenhouseSensorType.lightLevel]!,
        measuredAt: ts.toLocal(),
      );
    }).toList();
  }
}

/// Consumes API Platform endpoints exposed by the GreenHouse Symfony backend.
class GreenhouseApiService {
  GreenhouseApiService({
    required this.session,
    http.Client? client,
    Duration? requestTimeout,
  })  : _client = client ?? http.Client(),
        _requestTimeout = requestTimeout ?? defaultRequestTimeout;

  static const Duration defaultRequestTimeout = Duration(seconds: 25);

  final AuthSession session;
  final http.Client _client;
  final Duration _requestTimeout;

  static const int _maxPages = 50;

  Map<String, String> get _readHeaders => {
        'Accept': ApiConfig.jsonLdContentType,
        'Authorization': 'Bearer ${session.token}',
      };

  Map<String, String> get _writeHeaders => {
        'Content-Type': ApiConfig.jsonLdContentType,
        'Accept': ApiConfig.jsonLdContentType,
        'Authorization': 'Bearer ${session.token}',
      };

  /// Fetches all [Device]s owned by [session.userId].
  Future<List<Device>> fetchUserDevices() async {
    final items = await _getCollection('/api/devices');
    return items
        .map(Device.fromJson)
        .where((device) => device.ownerId == session.userId)
        .toList();
  }

  /// Fetches all [Sensor]s belonging to [deviceId].
  Future<List<Sensor>> fetchSensorsForDevice(int deviceId) async {
    final items = await _getCollection('/api/sensors');
    return items
        .map(Sensor.fromJson)
        .where((sensor) => sensor.deviceId == deviceId)
        .toList();
  }

  /// Fetches all [Measurement]s belonging to [sensorIds], sorted oldest-first.
  Future<List<Measurement>> fetchMeasurementsForSensors(
    Set<int> sensorIds,
  ) async {
    if (sensorIds.isEmpty) return const [];
    final items = await _getCollection('/api/measurements');
    final measurements = items
        .map(Measurement.fromJson)
        .where((m) => m.sensorId != null && sensorIds.contains(m.sensorId))
        .toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return measurements;
  }

  /// Loads a complete [GreenhouseSnapshot] for [device].
  Future<GreenhouseSnapshot> fetchDeviceSnapshot(Device device) async {
    final sensors = await fetchSensorsForDevice(device.id);
    return fetchMeasurementsSnapshot(device, sensors);
  }

  /// Refreshes only measurements for [device] using already-loaded [sensors].
  Future<GreenhouseSnapshot> fetchMeasurementsSnapshot(
    Device device,
    List<Sensor> sensors,
  ) async {
    final sensorIds = sensors.map((s) => s.id).toSet();
    final measurements = await fetchMeasurementsForSensors(sensorIds);
    return GreenhouseSnapshot(
      device: device,
      sensors: sensors,
      measurements: measurements,
    );
  }

  /// Fetches recent [DeviceCommand]s for [deviceId], newest first.
  Future<List<DeviceCommand>> fetchCommandsForDevice(int deviceId) async {
    final items = await _getCollection('/api/commands');
    final commands = items
        .map(DeviceCommand.fromJson)
        .where((cmd) => cmd.deviceId == deviceId)
        .toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return commands;
  }

  /// Sends a new actuator [DeviceCommand] via `POST /api/commands`.
  Future<DeviceCommand> sendCommand({
    required int deviceId,
    required String actuator,
    required String action,
    int? durationSeconds,
  }) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            ApiConfig.uri('/api/commands'),
            headers: _writeHeaders,
            body: jsonEncode({
              'actuator': actuator,
              'action': action,
              'durationSeconds': ?durationSeconds,
              'device': '/api/devices/$deviceId',
              'createdBy': session.userIri,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'Command request timed out after ${_requestTimeout.inSeconds} seconds.',
      );
    } catch (error) {
      throw ApiException('Unable to reach server: $error');
    }

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw ApiException(
        extractApiErrorMessage(response, fallback: 'Failed to send command'),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return DeviceCommand.fromJson(decoded);
  }

  Future<List<Map<String, dynamic>>> _getCollection(String initialPath) async {
    final results = <Map<String, dynamic>>[];
    String? nextPath = initialPath;
    var pageCount = 0;

    while (nextPath != null && pageCount < _maxPages) {
      pageCount++;
      late final http.Response response;
      try {
        response = await _client
            .get(
              ApiConfig.uri(nextPath),
              headers: _readHeaders,
            )
            .timeout(_requestTimeout);
      } on TimeoutException {
        throw ApiException(
          'Request to $nextPath timed out after ${_requestTimeout.inSeconds} seconds.',
        );
      } catch (error) {
        throw ApiException('Unable to reach server: $error');
      }

      if (response.statusCode != 200) {
        throw ApiException(
          extractApiErrorMessage(response, fallback: 'Failed to load data'),
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }

      final decoded = jsonDecode(response.body);
      results.addAll(extractJsonLdMembers(decoded));
      nextPath = extractNextPagePath(decoded);
    }

    return results;
  }
}
