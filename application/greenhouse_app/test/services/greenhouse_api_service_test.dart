import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/models/auth_session.dart';
import 'package:greenhouse_app/models/device.dart';
import 'package:greenhouse_app/models/sensor.dart';
import 'package:greenhouse_app/services/api_exception.dart';
import 'package:greenhouse_app/services/greenhouse_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const session = AuthSession(
    token: 'jwt-xyz',
    userId: 2,
    email: 'atef@example.com',
    firstName: 'Atef',
    lastName: 'B',
  );

  group('GreenhouseApiService', () {
    test('fetches devices, paginated measurements, and maps snapshot accurately', () async {
      final client = MockClient((request) async {
        expect(request.headers['Accept'], 'application/ld+json');
        expect(request.headers['Authorization'], 'Bearer jwt-xyz');

        if (request.url.path == '/api/devices') {
          return http.Response(
            jsonEncode({
              '@type': 'Collection',
              'member': [
                {
                  'id': 1,
                  'name': 'Serre Principale',
                  'location': 'Jardin',
                  'isActive': true,
                  'lastSeenAt': '2026-11-26T22:00:00Z',
                  'owner': '/api/users/2',
                },
                {
                  'id': 99,
                  'name': 'Autre Serre',
                  'isActive': true,
                  'owner': '/api/users/5',
                },
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/sensors') {
          return http.Response(
            jsonEncode({
              '@type': 'Collection',
              'member': [
                {'id': 10, 'type': 'temperature', 'unit': '°C', 'device': '/api/devices/1'},
                {'id': 11, 'type': 'air_humidity', 'unit': '%', 'device': '/api/devices/1'},
                {'id': 12, 'type': 'soil_moisture', 'unit': '%', 'device': '/api/devices/1'},
                {'id': 13, 'type': 'light_level', 'unit': 'lux', 'device': '/api/devices/1'},
                {'id': 14, 'type': 'temperature', 'unit': '°C', 'device': '/api/devices/99'},
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/measurements' &&
            request.url.queryParameters['page'] != '2') {
          return http.Response(
            jsonEncode({
              '@type': 'Collection',
              'member': [
                {
                  'id': 1,
                  'value': 24.0,
                  'measuredAt': '2026-11-26T20:00:00Z',
                  'sensor': '/api/sensors/10',
                },
                {
                  'id': 2,
                  'value': 60.0,
                  'measuredAt': '2026-11-26T20:00:00Z',
                  'sensor': '/api/sensors/11',
                },
              ],
              'view': {'next': '/api/measurements?page=2'},
            }),
            200,
          );
        }

        if (request.url.path == '/api/measurements' &&
            request.url.queryParameters['page'] == '2') {
          return http.Response(
            jsonEncode({
              '@type': 'Collection',
              'member': [
                {
                  'id': 3,
                  'value': 29.5,
                  'measuredAt': '2026-11-26T22:00:00Z',
                  'sensor': '/api/sensors/10',
                },
                {
                  'id': 4,
                  'value': 42.0,
                  'measuredAt': '2026-11-26T22:00:00Z',
                  'sensor': '/api/sensors/12',
                },
                {
                  'id': 5,
                  'value': 820.0,
                  'measuredAt': '2026-11-26T22:00:00Z',
                  'sensor': '/api/sensors/13',
                },
              ],
            }),
            200,
          );
        }

        return http.Response('Not found', 404);
      });

      final api = GreenhouseApiService(session: session, client: client);
      final devices = await api.fetchUserDevices();
      expect(devices, hasLength(1));
      expect(devices.first.name, 'Serre Principale');

      final snapshot = await api.fetchDeviceSnapshot(devices.first);
      expect(snapshot.sensors, hasLength(4));
      expect(snapshot.measurements, hasLength(5));

      final latest = snapshot.latestReading;
      expect(latest, isNotNull);
      expect(latest!.temperature, 29.5);
      expect(latest.airHumidity, 60.0);
      expect(latest.soilMoisture, 42.0);
      expect(latest.lightLevel, 820.0);

      final history = snapshot.historyForLookback(
        const Duration(hours: 24),
        referenceTime: DateTime.utc(2026, 11, 26, 22, 30),
      );
      expect(history, hasLength(2));
      expect(history.first.temperature, 24.0);
      expect(history.last.temperature, 29.5);
      // Pre-seeded so soilMoisture is not 0.0 on the first bucket.
      expect(history.first.soilMoisture, 42.0);
    });

    test('sendCommand sends JSON-LD payload with device and user IRIs', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/commands');
        expect(
          request.headers['Content-Type'],
          startsWith('application/ld+json'),
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['actuator'], 'pump');
        expect(body['action'], 'ON');
        expect(body['durationSeconds'], 30);
        expect(body['device'], '/api/devices/1');
        expect(body['createdBy'], '/api/users/2');

        return http.Response(
          jsonEncode({
            'id': 55,
            'actuator': 'pump',
            'action': 'ON',
            'durationSeconds': 30,
            'status': 'pending',
            'device': '/api/devices/1',
            'createdBy': '/api/users/2',
          }),
          201,
        );
      });

      final api = GreenhouseApiService(session: session, client: client);
      final cmd = await api.sendCommand(
        deviceId: 1,
        actuator: 'pump',
        action: 'ON',
        durationSeconds: 30,
      );

      expect(cmd.id, 55);
      expect(cmd.status, 'pending');
    });

    test('fetchMeasurementsSnapshot skips devices and sensors endpoints', () async {
      final calledPaths = <String>[];
      final client = MockClient((request) async {
        calledPaths.add(request.url.path);
        return http.Response(
          jsonEncode({
            '@type': 'Collection',
            'member': [
              {
                'id': 1,
                'value': 26.2,
                'measuredAt': '2026-11-26T22:00:00Z',
                'sensor': '/api/sensors/10',
              },
            ],
          }),
          200,
        );
      });

      final api = GreenhouseApiService(session: session, client: client);
      const device = Device(id: 1, name: 'Serre', isActive: true);
      const sensors = [
        Sensor(id: 10, type: 'temperature', unit: '°C', deviceIri: '/api/devices/1'),
      ];

      final snapshot = await api.fetchMeasurementsSnapshot(device, sensors);
      expect(calledPaths, ['/api/measurements']);
      expect(snapshot.latestReading?.temperature, 26.2);
    });

    test('times out cleanly when collection endpoint hangs', () async {
      final completer = Completer<http.Response>();
      final api = GreenhouseApiService(
        session: session,
        client: MockClient((_) => completer.future),
        requestTimeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        api.fetchUserDevices,
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });
  });
}
