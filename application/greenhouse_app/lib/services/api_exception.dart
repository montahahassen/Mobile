import 'dart:convert';

import 'package:http/http.dart' as http;

/// Represents an HTTP or API-level error returned by the GreenHouse backend.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  /// Creates an [ApiException] with a user-friendly [message].
  const ApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
  });

  /// Whether the backend rejected the request due to expired or missing auth.
  bool get isUnauthorized => statusCode == 401;

  /// Formats a detailed diagnostic string including HTTP status and body.
  String toDetailedString() {
    final buffer = StringBuffer(message);
    if (statusCode != null) {
      buffer.write('\nHTTP Status: $statusCode');
    }
    final body = responseBody?.trim();
    if (body != null && body.isNotEmpty) {
      buffer.write('\nResponse: $body');
    }
    return buffer.toString();
  }

  @override
  String toString() => message;
}

/// Extracts a readable error message from a Symfony / API Platform response.
String extractApiErrorMessage(http.Response response, {String fallback = 'Request failed'}) {
  if (response.body.isEmpty) {
    return '$fallback (HTTP ${response.statusCode})';
  }
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final violations = decoded['violations'];
      if (violations is List && violations.isNotEmpty) {
        final messages = violations
            .whereType<Map<String, dynamic>>()
            .map((v) => v['message'])
            .whereType<String>()
            .where((m) => m.trim().isNotEmpty)
            .toList();
        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      }
      for (final key in ['detail', 'message', 'error', 'title']) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }
  } catch (_) {
    // Non-JSON response body; fall back to status summary below.
  }
  return '$fallback (HTTP ${response.statusCode})';
}
