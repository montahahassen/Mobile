import 'api_helpers.dart';

/// Represents an actuator command from `/api/commands`.
class DeviceCommand {
  final int id;
  final String actuator;
  final String action;
  final int? durationSeconds;
  final String status;
  final DateTime? createdAt;
  final DateTime? executedAt;
  final String? deviceIri;
  final String? createdByIri;

  /// Creates an immutable [DeviceCommand].
  const DeviceCommand({
    required this.id,
    required this.actuator,
    required this.action,
    this.durationSeconds,
    required this.status,
    this.createdAt,
    this.executedAt,
    this.deviceIri,
    this.createdByIri,
  });

  /// Numeric target device ID parsed from [deviceIri].
  int? get deviceId => extractIdFromIri(deviceIri);

  /// Parses a [DeviceCommand] from an API Platform JSON-LD item.
  factory DeviceCommand.fromJson(Map<String, dynamic> json) {
    final parsedId = (json['id'] as num?)?.toInt() ?? extractIdFromIri(json['@id']) ?? 0;
    return DeviceCommand(
      id: parsedId,
      actuator: (json['actuator'] as String?) ?? '',
      action: (json['action'] as String?) ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      status: (json['status'] as String?) ?? 'pending',
      createdAt: parseNullableDateTime(json['createdAt']),
      executedAt: parseNullableDateTime(json['executedAt']),
      deviceIri: extractIriString(json['device']),
      createdByIri: extractIriString(json['createdBy']),
    );
  }
}
