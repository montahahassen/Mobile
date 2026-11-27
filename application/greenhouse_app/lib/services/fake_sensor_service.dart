import 'dart:math' as math;

import '../models/sensor_reading.dart';

/// Provides provisional fake sensor data for Demo Mode.
class FakeSensorService {
  /// Returns a sample [SensorReading] for dashboard display without a backend.
  static SensorReading getFakeReading({DateTime? measuredAt}) {
    return SensorReading(
      temperature: 28.5,
      airHumidity: 65.0,
      soilMoisture: 40.0,
      lightLevel: 750.0,
      measuredAt: measuredAt ?? DateTime.now(),
    );
  }

  /// Generates the next deterministic simulated live [SensorReading] for [tick].
  ///
  /// Only temperature varies gradually between 27.0 °C and 30.0 °C; all other
  /// sensor values remain fixed and [measuredAt] defaults to `DateTime.now()`.
  static SensorReading getNextLiveReading(int tick, {DateTime? measuredAt}) {
    final temperature = _roundOneDecimal(
      (28.5 + 1.2 * math.sin(tick * 0.5)).clamp(27.0, 30.0),
    );

    return SensorReading(
      temperature: temperature,
      airHumidity: 65.0,
      soilMoisture: 40.0,
      lightLevel: 750.0,
      measuredAt: measuredAt ?? DateTime.now(),
    );
  }

  /// Generates a deterministic list of simulated historical [SensorReading]s.
  ///
  /// Readings are ordered chronologically from oldest to newest, with the most
  /// recent entry timestamped at [referenceTime] (or `DateTime.now()`).
  static List<SensorReading> getFakeHistory({
    int count = 13,
    Duration interval = const Duration(hours: 2),
    DateTime? referenceTime,
  }) {
    if (count <= 0) {
      return const [];
    }

    final endTime = referenceTime ?? DateTime.now();

    return List<SensorReading>.generate(count, (index) {
      final stepsFromEnd = count - 1 - index;
      final measuredAt = endTime.subtract(interval * stepsFromEnd);

      // Deterministic smooth curves anchored near the current demo readings.
      final temperature = _roundOneDecimal(
        (28.5 -
                2.8 * math.sin(stepsFromEnd * 0.75) -
                0.6 * (1 - math.cos(stepsFromEnd * 0.45)))
            .clamp(18.0, 36.0),
      );
      final airHumidity = _roundOneDecimal(
        (65.0 +
                7.5 * math.sin(stepsFromEnd * 0.65) -
                2.0 * (1 - math.cos(stepsFromEnd * 0.4)))
            .clamp(35.0, 90.0),
      );
      final soilMoisture = _roundOneDecimal(
        (40.0 +
                5.5 * (math.sin(stepsFromEnd * 0.45 + 0.5) - math.sin(0.5)) +
                1.5 * (1 - math.cos(stepsFromEnd * 0.35)))
            .clamp(20.0, 75.0),
      );
      final lightLevel = _roundOneDecimal(
        (750.0 -
                210.0 * (1 - math.cos(stepsFromEnd * 0.8)) -
                75.0 * math.sin(stepsFromEnd * 0.55))
            .clamp(80.0, 1000.0),
      );

      return SensorReading(
        temperature: temperature,
        airHumidity: airHumidity,
        soilMoisture: soilMoisture,
        lightLevel: lightLevel,
        measuredAt: measuredAt,
      );
    });
  }

  static double _roundOneDecimal(double value) {
    return double.parse(value.toStringAsFixed(1));
  }
}
