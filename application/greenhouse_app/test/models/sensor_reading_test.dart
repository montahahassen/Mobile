import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/models/sensor_reading.dart';

void main() {
  group('SensorReading', () {
    test('fromJson converts JSON into a SensorReading object', () {
      final json = <String, dynamic>{
        'temperature': 28.5,
        'airHumidity': 65.0,
        'soilMoisture': 40.0,
        'lightLevel': 750.0,
        'measuredAt': '2026-11-26T10:30:00.000Z',
      };

      final reading = SensorReading.fromJson(json);

      expect(reading.temperature, 28.5);
      expect(reading.airHumidity, 65.0);
      expect(reading.soilMoisture, 40.0);
      expect(reading.lightLevel, 750.0);
      expect(reading.measuredAt, DateTime.utc(2026, 11, 26, 10, 30));
    });

    test('fromJson converts integer JSON values into doubles', () {
      final json = <String, dynamic>{
        'temperature': 28,
        'airHumidity': 65,
        'soilMoisture': 40,
        'lightLevel': 750,
        'measuredAt': '2026-11-26T10:30:00.000Z',
      };

      final reading = SensorReading.fromJson(json);

      expect(reading.temperature, isA<double>());
      expect(reading.airHumidity, isA<double>());
      expect(reading.soilMoisture, isA<double>());
      expect(reading.lightLevel, isA<double>());

      expect(reading.temperature, 28.0);
      expect(reading.airHumidity, 65.0);
      expect(reading.soilMoisture, 40.0);
      expect(reading.lightLevel, 750.0);
    });

    test('toJson returns expected Map with ISO 8601 measuredAt', () {
      final timestamp = DateTime.utc(2026, 11, 26, 10, 30);
      final reading = SensorReading(
        temperature: 28.5,
        airHumidity: 65.0,
        soilMoisture: 40.0,
        lightLevel: 750.0,
        measuredAt: timestamp,
      );

      final json = reading.toJson();

      expect(json, <String, dynamic>{
        'temperature': 28.5,
        'airHumidity': 65.0,
        'soilMoisture': 40.0,
        'lightLevel': 750.0,
        'measuredAt': timestamp.toIso8601String(),
      });
      expect(json['measuredAt'], '2026-11-26T10:30:00.000Z');
    });

    test('JSON round trip preserves all sensor values and timestamp', () {
      final originalJson = <String, dynamic>{
        'temperature': 28.5,
        'airHumidity': 65.0,
        'soilMoisture': 40.0,
        'lightLevel': 750.0,
        'measuredAt': '2026-11-26T10:30:00.000Z',
      };

      final reading = SensorReading.fromJson(originalJson);
      final roundTrippedJson = reading.toJson();

      expect(roundTrippedJson, equals(originalJson));
    });
  });
}
