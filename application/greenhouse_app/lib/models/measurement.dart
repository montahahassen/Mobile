import 'api_helpers.dart';

/// Represents a single sensor measurement from `/api/measurements`.
class Measurement {
  final int id;
  final double value;
  final DateTime measuredAt;
  final DateTime? createdAt;
  final String? sensorIri;

  /// Creates an immutable [Measurement].
  const Measurement({
    required this.id,
    required this.value,
    required this.measuredAt,
    this.createdAt,
    this.sensorIri,
  });

  /// Numeric parent sensor ID parsed from [sensorIri].
  int? get sensorId => extractIdFromIri(sensorIri);

  /// Parses a [Measurement] from an API Platform JSON-LD item.
  factory Measurement.fromJson(Map<String, dynamic> json) {
    final parsedId = (json['id'] as num?)?.toInt() ?? extractIdFromIri(json['@id']) ?? 0;
    return Measurement(
      id: parsedId,
      value: (json['value'] as num).toDouble(),
      measuredAt: parseNullableDateTime(json['measuredAt']) ??
          parseNullableDateTime(json['createdAt']) ??
          DateTime.now(),
      createdAt: parseNullableDateTime(json['createdAt']),
      sensorIri: extractIriString(json['sensor']),
    );
  }
}
