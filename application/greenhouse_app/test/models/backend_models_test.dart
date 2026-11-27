import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/config/api_config.dart';
import 'package:greenhouse_app/models/api_helpers.dart';
import 'package:greenhouse_app/models/auth_session.dart';
import 'package:greenhouse_app/models/command.dart';
import 'package:greenhouse_app/models/device.dart';
import 'package:greenhouse_app/models/measurement.dart';
import 'package:greenhouse_app/models/sensor.dart';

void main() {
  group('ApiConfig & helpers', () {
    test('ApiConfig builds URIs with normalized slashes and query params', () {
      expect(
        ApiConfig.uri('/api/devices').toString(),
        'http://10.0.2.2:8000/api/devices',
      );
      expect(
        ApiConfig.uri('api/measurements', {'page': '2'}).toString(),
        'http://10.0.2.2:8000/api/measurements?page=2',
      );
    });

    test('extractIdFromIri parses IRI strings, ints, and nested maps', () {
      expect(extractIdFromIri('/api/devices/12'), 12);
      expect(extractIdFromIri(7), 7);
      expect(extractIdFromIri({'@id': '/api/users/4'}), 4);
      expect(extractIdFromIri({'id': 9}), 9);
      expect(extractIdFromIri(''), isNull);
    });

    test('extractJsonLdMembers and extractNextPagePath handle API Platform 5', () {
      final payload = <String, dynamic>{
        '@context': '/api/contexts/Measurement',
        '@id': '/api/measurements',
        '@type': 'Collection',
        'totalItems': 35,
        'member': [
          {'id': 1, 'value': 24.5},
          {'id': 2, 'value': 25.0},
        ],
        'view': {
          '@id': '/api/measurements?page=1',
          'next': '/api/measurements?page=2',
        },
      };

      expect(extractJsonLdMembers(payload), hasLength(2));
      expect(extractNextPagePath(payload), '/api/measurements?page=2');
    });
  });

  group('Backend models', () {
    test('AuthSession parses POST /auth payload with lowercase names', () {
      final session = AuthSession.fromJson(<String, dynamic>{
        'token': 'jwt-abc',
        'id': 3,
        'firstname': 'Atef',
        'lastname': 'Ben',
        'email': 'atef@example.com',
      });

      expect(session.token, 'jwt-abc');
      expect(session.userId, 3);
      expect(session.userIri, '/api/users/3');
      expect(session.displayName, 'Atef Ben');
      expect(AuthSession.fromJson(session.toJson()).email, 'atef@example.com');
    });

    test('Device parses both isActive and active fields', () {
      final device = Device.fromJson(<String, dynamic>{
        '@id': '/api/devices/1',
        'id': 1,
        'name': 'Serre Nord',
        'location': 'Tunis',
        'active': false,
        'lastSeenAt': '2026-11-26T20:00:00+00:00',
        'owner': '/api/users/2',
        'sensors': ['/api/sensors/1', '/api/sensors/2'],
      });

      expect(device.id, 1);
      expect(device.name, 'Serre Nord');
      expect(device.isActive, isFalse);
      expect(device.ownerId, 2);
      expect(device.sensorIris, ['/api/sensors/1', '/api/sensors/2']);
    });

    test('Sensor normalizes common backend sensor type variants', () {
      expect(
        Sensor.fromJson({'id': 1, 'type': 'temperature', 'unit': '°C'})
            .normalizedType,
        GreenhouseSensorType.temperature,
      );
      expect(
        Sensor.fromJson({'id': 2, 'type': 'air_humidity', 'unit': '%'})
            .normalizedType,
        GreenhouseSensorType.airHumidity,
      );
      expect(
        Sensor.fromJson({'id': 3, 'type': 'soil_moisture', 'unit': '%'})
            .normalizedType,
        GreenhouseSensorType.soilMoisture,
      );
      expect(
        Sensor.fromJson({
          'id': 4,
          'type': 'light_level',
          'unit': 'lux',
          'device': '/api/devices/5',
        }).deviceId,
        5,
      );
    });

    test('Measurement and DeviceCommand parse JSON-LD items', () {
      final m = Measurement.fromJson(<String, dynamic>{
        'id': 10,
        'value': 29,
        'measuredAt': '2026-11-26T21:15:00Z',
        'sensor': '/api/sensors/1',
      });
      expect(m.value, 29.0);
      expect(m.sensorId, 1);

      final cmd = DeviceCommand.fromJson(<String, dynamic>{
        'id': 4,
        'actuator': 'pump',
        'action': 'ON',
        'durationSeconds': 30,
        'status': 'pending',
        'device': '/api/devices/1',
        'createdBy': '/api/users/2',
      });
      expect(cmd.actuator, 'pump');
      expect(cmd.action, 'ON');
      expect(cmd.durationSeconds, 30);
      expect(cmd.deviceId, 1);
    });
  });
}
