import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/models/auth_session.dart';
import 'package:greenhouse_app/services/api_exception.dart';
import 'package:greenhouse_app/services/auth_service.dart';
import 'package:greenhouse_app/services/session_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AuthService', () {
    test('login sends JSON credentials to /auth and saves session', () async {
      final storage = InMemorySessionStorage();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(request.headers['Accept'], 'application/json');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'atef@example.com');
        expect(body['password'], 'secret123');

        return http.Response(
          jsonEncode({
            'token': 'jwt-token-123',
            'id': 7,
            'firstname': 'Atef',
            'lastname': 'B',
            'email': 'atef@example.com',
          }),
          200,
        );
      });

      final service = AuthService(client: client, storage: storage);
      final session = await service.login(
        email: ' atef@example.com ',
        password: 'secret123',
      );

      expect(session.token, 'jwt-token-123');
      expect(session.userId, 7);

      final loaded = await service.loadSession();
      expect(loaded, isNotNull);
      expect(loaded!.token, 'jwt-token-123');

      await service.logout();
      expect(await service.loadSession(), isNull);
    });

    test('login throws ApiException on 401 invalid credentials', () async {
      final service = AuthService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'code': 401, 'message': 'Invalid credentials.'}),
            401,
          ),
        ),
        storage: InMemorySessionStorage(),
      );

      expect(
        () => service.login(email: 'bad@example.com', password: 'wrong'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)
              .having((e) => e.message, 'message', 'Invalid credentials.'),
        ),
      );
    });

    test('register sends JSON-LD to /api/users then logs in automatically', () async {
      final storage = InMemorySessionStorage();
      final calls = <String>[];

      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/users') {
          expect(
            request.headers['Content-Type'],
            startsWith('application/ld+json'),
          );
          expect(request.headers['Accept'], 'application/ld+json');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['firstName'], 'Montaha');
          expect(body['lastName'], 'Hassen');
          expect(body['email'], 'montaha@example.com');
          return http.Response(
            jsonEncode({'@id': '/api/users/9', 'id': 9}),
            201,
          );
        }
        if (request.url.path == '/auth') {
          return http.Response(
            jsonEncode({
              'token': 'new-user-jwt',
              'id': 9,
              'firstname': 'Montaha',
              'lastname': 'Hassen',
              'email': 'montaha@example.com',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = AuthService(client: client, storage: storage);
      final AuthSession session = await service.register(
        firstName: 'Montaha',
        lastName: 'Hassen',
        email: 'montaha@example.com',
        password: 'Password123',
      );

      expect(calls, ['POST /api/users', 'POST /auth']);
      expect(session.userId, 9);
      expect(session.token, 'new-user-jwt');
    });

    test('register preserves HTTP status code and response body on failure', () async {
      const rawBody = '{"detail":"email: Cet email est deja utilise."}';
      final service = AuthService(
        client: MockClient((_) async => http.Response(rawBody, 422)),
        storage: InMemorySessionStorage(),
      );

      await expectLater(
        () => service.register(
          firstName: 'Test',
          lastName: 'User',
          email: 'dup@example.com',
          password: 'Password123',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.responseBody, 'responseBody', rawBody),
        ),
      );
    });

    test('register times out cleanly instead of hanging indefinitely', () async {
      final completer = Completer<http.Response>();
      final service = AuthService(
        client: MockClient((_) => completer.future),
        storage: InMemorySessionStorage(),
        requestTimeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        () => service.register(
          firstName: 'Test',
          lastName: 'User',
          email: 'slow@example.com',
          password: 'Password123',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });
  });
}
