/// Model representing a single greenhouse sensor reading.
class SensorReading {
  final double temperature;
  final double airHumidity;
  final double soilMoisture;
  final double lightLevel;
  final DateTime measuredAt;

  /// Creates an immutable [SensorReading] instance.
  const SensorReading({
    required this.temperature,
    required this.airHumidity,
    required this.soilMoisture,
    required this.lightLevel,
    required this.measuredAt,
  });

  /// Creates a [SensorReading] from a JSON map using provisional field names.
  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      temperature: (json['temperature'] as num).toDouble(),
      airHumidity: (json['airHumidity'] as num).toDouble(),
      soilMoisture: (json['soilMoisture'] as num).toDouble(),
      lightLevel: (json['lightLevel'] as num).toDouble(),
      measuredAt: DateTime.parse(json['measuredAt'] as String),
    );
  }

  /// Converts this [SensorReading] into a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'airHumidity': airHumidity,
      'soilMoisture': soilMoisture,
      'lightLevel': lightLevel,
      'measuredAt': measuredAt.toIso8601String(),
    };
  }
}
