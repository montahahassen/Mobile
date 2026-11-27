import 'api_helpers.dart';

/// Supported greenhouse sensor categories mapped from backend `Sensor.type`.
enum GreenhouseSensorType {
  temperature,
  airHumidity,
  soilMoisture,
  lightLevel,
}

/// Represents a sensor attached to a [Device] from `/api/sensors`.
class Sensor {
  final int id;
  final String type;
  final String unit;
  final String? label;
  final String? deviceIri;

  /// Creates an immutable [Sensor].
  const Sensor({
    required this.id,
    required this.type,
    required this.unit,
    this.label,
    this.deviceIri,
  });

  /// API Platform IRI for this sensor (`/api/sensors/{id}`).
  String get iri => '/api/sensors/$id';

  /// Numeric parent device ID parsed from [deviceIri].
  int? get deviceId => extractIdFromIri(deviceIri);

  /// Maps backend [type] strings flexibly to a [GreenhouseSensorType].
  GreenhouseSensorType? get normalizedType {
    final key = type.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return switch (key) {
      'temperature' || 'temp' => GreenhouseSensorType.temperature,
      'airhumidity' || 'humidity' || 'hum' => GreenhouseSensorType.airHumidity,
      'soilmoisture' || 'soil' || 'moisture' => GreenhouseSensorType.soilMoisture,
      'lightlevel' || 'light' || 'luminosity' || 'lux' =>
        GreenhouseSensorType.lightLevel,
      _ => null,
    };
  }

  /// Parses a [Sensor] from an API Platform JSON-LD item.
  factory Sensor.fromJson(Map<String, dynamic> json) {
    final parsedId = (json['id'] as num?)?.toInt() ?? extractIdFromIri(json['@id']) ?? 0;
    return Sensor(
      id: parsedId,
      type: (json['type'] as String?) ?? '',
      unit: (json['unit'] as String?) ?? '',
      label: json['label'] as String?,
      deviceIri: extractIriString(json['device']),
    );
  }
}
