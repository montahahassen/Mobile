import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/auth_session.dart';
import 'api_exception.dart';
import 'session_storage.dart';

/// Handles user authentication (`POST /auth`), registration, and local session state.
class AuthService {
  AuthService({
    http.Client? client,
    SessionStorage? storage,
    Duration? requestTimeout,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? createDefaultSessionStorage(),
        _requestTimeout = requestTimeout ?? defaultRequestTimeout;

  static const Duration defaultRequestTimeout = Duration(seconds: 25);

  final http.Client _client;
  final SessionStorage _storage;
  final Duration _requestTimeout;

  /// Authenticates a user against `POST /auth` and persists the JWT session.
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            ApiConfig.uri('/auth'),
            headers: const {
              'Content-Type': ApiConfig.jsonContentType,
              'Accept': ApiConfig.jsonContentType,
            },
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'Login request timed out after ${_requestTimeout.inSeconds} seconds.',
      );
    } catch (error) {
      throw ApiException('Unable to reach server: $error');
    }

    if (response.statusCode != 200) {
      final fallback = response.statusCode == 401
          ? 'Invalid email or password.'
          : 'Login failed';
      throw ApiException(
        extractApiErrorMessage(response, fallback: fallback),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final session = AuthSession.fromJson(decoded);
    await _storage.write(jsonEncode(session.toJson()));
    return session;
  }

  /// Registers a new user via `POST /api/users` and signs them in immediately.
  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    late final http.Response response;
    try {
      response = await _client
          .post(
            ApiConfig.uri('/api/users'),
            headers: const {
              'Content-Type': ApiConfig.jsonLdContentType,
              'Accept': ApiConfig.jsonLdContentType,
            },
            body: jsonEncode({
              'firstName': firstName.trim(),
              'lastName': lastName.trim(),
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'Registration request timed out after ${_requestTimeout.inSeconds} seconds.',
      );
    } catch (error) {
      throw ApiException('Unable to reach server: $error');
    }

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw ApiException(
        extractApiErrorMessage(response, fallback: 'Registration failed'),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    try {
      return await login(email: email, password: password);
    } on ApiException catch (error) {
      throw ApiException(
        'Account created, but automatic login failed: ${error.message}',
        statusCode: error.statusCode,
        responseBody: error.responseBody,
      );
    }
  }

  /// Loads a previously saved [AuthSession], or `null` if none exists.
  Future<AuthSession?> loadSession() async {
    final raw = await _storage.read();
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AuthSession.fromJson(decoded);
    } catch (_) {
      await _storage.delete();
      return null;
    }
  }

  /// Clears the persisted [AuthSession].
  Future<void> logout() async {
    await _storage.delete();
  }
}
