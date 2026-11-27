/// Extracts a numeric resource ID from an API Platform IRI, int, or nested map.
int? extractIdFromIri(dynamic value) {
  if (value is int) return value;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final segments = trimmed.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    return int.tryParse(segments.last);
  }
  if (value is Map<String, dynamic>) {
    if (value['id'] is int) return value['id'] as int;
    if (value['@id'] != null) return extractIdFromIri(value['@id']);
  }
  return null;
}

/// Extracts an IRI string from either a string IRI or an embedded JSON-LD object.
String? extractIriString(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  if (value is Map<String, dynamic> && value['@id'] is String) {
    return value['@id'] as String;
  }
  return null;
}

/// Extracts a list of IRI strings from a JSON-LD relation array.
List<String> extractIriList(dynamic value) {
  if (value is! List) return const [];
  return value.map(extractIriString).whereType<String>().toList();
}

/// Extracts collection items from an API Platform JSON-LD payload or plain list.
List<Map<String, dynamic>> extractJsonLdMembers(dynamic decoded) {
  if (decoded is List) {
    return decoded.whereType<Map<String, dynamic>>().toList();
  }
  if (decoded is Map<String, dynamic>) {
    final rawMembers = decoded['member'] ?? decoded['hydra:member'];
    if (rawMembers is List) {
      return rawMembers.whereType<Map<String, dynamic>>().toList();
    }
  }
  return const [];
}

/// Extracts the next-page relative path from an API Platform JSON-LD collection.
String? extractNextPagePath(dynamic decoded) {
  if (decoded is! Map<String, dynamic>) return null;
  final view = decoded['view'] ?? decoded['hydra:view'];
  if (view is Map<String, dynamic>) {
    final next = view['next'] ?? view['hydra:next'];
    if (next is String && next.isNotEmpty) {
      return next;
    }
  }
  return null;
}

/// Parses an ISO 8601 string into a [DateTime], returning `null` if invalid.
DateTime? parseNullableDateTime(dynamic value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}
