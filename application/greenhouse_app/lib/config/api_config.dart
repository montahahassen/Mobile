/// Network configuration for connecting to the GreenHouse Symfony backend.
class ApiConfig {
  /// Base URL defaulting to the Android Emulator host alias (`10.0.2.2:8000`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Standard JSON media type used by the `/auth` endpoint.
  static const String jsonContentType = 'application/json';

  /// JSON-LD media type required by API Platform 5 endpoints under `/api`.
  static const String jsonLdContentType = 'application/ld+json';

  /// Builds a full [Uri] from a relative [path] and optional [queryParameters].
  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final parsed = Uri.parse('$normalizedBase$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return parsed;
    }
    return parsed.replace(queryParameters: queryParameters);
  }
}
