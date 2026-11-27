import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/services/fake_sensor_service.dart';

void main() {
  group('FakeSensorService', () {
    test('getFakeReading keeps expected current demo values', () {
      final reading = FakeSensorService.getFakeReading();

      expect(reading.temperature, 28.5);
      expect(reading.airHumidity, 65.0);
      expect(reading.soilMoisture, 40.0);
      expect(reading.lightLevel, 750.0);
    });

    test('getNextLiveReading updates temperature gradually and keeps other sensors constant', () {
      var previousTemp = FakeSensorService.getFakeReading().temperature;

      for (var tick = 1; tick <= 30; tick++) {
        final reading = FakeSensorService.getNextLiveReading(tick);

        expect(reading.temperature, inInclusiveRange(27.0, 30.0));
        expect(
          (reading.temperature - previousTemp).abs(),
          lessThanOrEqualTo(0.7),
        );
        expect(reading.airHumidity, 65.0);
        expect(reading.soilMoisture, 40.0);
        expect(reading.lightLevel, 750.0);

        previousTemp = reading.temperature;
      }

      final firstTick = FakeSensorService.getNextLiveReading(1);
      final firstTickRepeat = FakeSensorService.getNextLiveReading(1);
      expect(firstTick.temperature, firstTickRepeat.temperature);
      expect(firstTick.temperature, isNot(28.5));
    });

    test('getFakeHistory supports requested counts and intervals', () {
      final ref = DateTime.utc(2026, 11, 26, 12, 0);

      final history24h = FakeSensorService.getFakeHistory(
        count: 13,
        interval: const Duration(hours: 2),
        referenceTime: ref,
      );
      expect(history24h, hasLength(13));
      expect(
        history24h.first.measuredAt,
        ref.subtract(const Duration(hours: 24)),
      );
      expect(history24h.last.measuredAt, ref);

      final history7d = FakeSensorService.getFakeHistory(
        count: 7,
        interval: const Duration(days: 1),
        referenceTime: ref,
      );
      expect(history7d, hasLength(7));
      expect(history7d.first.measuredAt, ref.subtract(const Duration(days: 6)));
      expect(history7d.last.measuredAt, ref);

      final history30d = FakeSensorService.getFakeHistory(
        count: 15,
        interval: const Duration(days: 2),
        referenceTime: ref,
      );
      expect(history30d, hasLength(15));
      expect(
        history30d.first.measuredAt,
        ref.subtract(const Duration(days: 28)),
      );
      expect(history30d.last.measuredAt, ref);
    });

    test(
      'getFakeHistory is deterministic and keeps distinct timestamps in range',
      () {
        final ref = DateTime.utc(2026, 11, 26, 12, 0);

        final firstRun = FakeSensorService.getFakeHistory(
          count: 13,
          interval: const Duration(hours: 2),
          referenceTime: ref,
        );
        final secondRun = FakeSensorService.getFakeHistory(
          count: 13,
          interval: const Duration(hours: 2),
          referenceTime: ref,
        );

        for (var i = 0; i < firstRun.length; i++) {
          expect(firstRun[i].toJson(), equals(secondRun[i].toJson()));
          expect(firstRun[i].temperature, inInclusiveRange(18.0, 36.0));
          expect(firstRun[i].airHumidity, inInclusiveRange(35.0, 90.0));
          expect(firstRun[i].soilMoisture, inInclusiveRange(20.0, 75.0));
          expect(firstRun[i].lightLevel, inInclusiveRange(80.0, 1000.0));

          if (i > 0) {
            expect(
              firstRun[i].measuredAt.isAfter(firstRun[i - 1].measuredAt),
              isTrue,
            );
          }
        }
      },
    );
  });
}
