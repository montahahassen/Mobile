import 'api_helpers.dart';

/// Represents an ESP32 greenhouse device exposed by `/api/devices`.
class Device {
  final int id;
  final String name;
  final String? location;
  final bool isActive;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final String? ownerIri;
  final List<String> sensorIris;
  final List<String> commandIris;

  /// Creates an immutable [Device].
  const Device({
    required this.id,
    required this.name,
    this.location,
    required this.isActive,
    this.lastSeenAt,
    this.createdAt,
    this.ownerIri,
    this.sensorIris = const [],
    this.commandIris = const [],
  });

  /// API Platform IRI for this device (`/api/devices/{id}`).
  String get iri => '/api/devices/$id';

  /// Numeric owner user ID parsed from [ownerIri].
  int? get ownerId => extractIdFromIri(ownerIri);

  /// Parses a [Device] from an API Platform JSON-LD item.
  factory Device.fromJson(Map<String, dynamic> json) {
    final parsedId = (json['id'] as num?)?.toInt() ?? extractIdFromIri(json['@id']) ?? 0;
    return Device(
      id: parsedId,
      name: (json['name'] as String?) ?? 'ESP32 Device',
      location: json['location'] as String?,
      isActive: (json['isActive'] as bool?) ?? (json['active'] as bool?) ?? true,
      lastSeenAt: parseNullableDateTime(json['lastSeenAt']),
      createdAt: parseNullableDateTime(json['createdAt']),
      ownerIri: extractIriString(json['owner']),
      sensorIris: extractIriList(json['sensors']),
      commandIris: extractIriList(json['commands']),
    );
  }
}
