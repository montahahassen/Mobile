import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/models/auth_session.dart';
import 'package:greenhouse_app/screens/login_screen.dart';
import 'package:greenhouse_app/screens/register_screen.dart';
import 'package:greenhouse_app/services/auth_service.dart';
import 'package:greenhouse_app/services/session_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('LoginScreen & RegisterScreen', () {
    testWidgets('shows validation errors on empty submit', (
      WidgetTester tester,
    ) async {
      final authService = AuthService(
        client: MockClient((_) async => http.Response('{}', 200)),
        storage: InMemorySessionStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authService: authService,
            onAuthenticated: (_) {},
            onDemoMode: () {},
          ),
        ),
      );

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('logs in and invokes onAuthenticated on valid credentials', (
      WidgetTester tester,
    ) async {
      AuthSession? received;
      final authService = AuthService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'token': 'jwt-ok',
              'id': 1,
              'firstname': 'Atef',
              'lastname': 'B',
              'email': 'atef@example.com',
            }),
            200,
          ),
        ),
        storage: InMemorySessionStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authService: authService,
            onAuthenticated: (session) => received = session,
            onDemoMode: () {},
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'atef@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(received, isNotNull);
      expect(received!.token, 'jwt-ok');
    });

    testWidgets('allows navigating to RegisterScreen and registering', (
      WidgetTester tester,
    ) async {
      AuthSession? received;
      final authService = AuthService(
        client: MockClient((request) async {
          if (request.url.path == '/api/users') {
            return http.Response(jsonEncode({'id': 4}), 201);
          }
          return http.Response(
            jsonEncode({
              'token': 'reg-jwt',
              'id': 4,
              'firstname': 'Sami',
              'lastname': 'T',
              'email': 'sami@example.com',
            }),
            200,
          );
        }),
        storage: InMemorySessionStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authService: authService,
            onAuthenticated: (session) => received = session,
            onDemoMode: () {},
          ),
        ),
      );

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsNWidgets(2));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'First Name'),
        'Sami',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last Name'),
        'T',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'sami@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(received, isNotNull);
      expect(received!.userId, 4);
    });

    testWidgets('RegisterScreen stops spinner and shows HTTP status and body on failure', (
      WidgetTester tester,
    ) async {
      final authService = AuthService(
        client: MockClient(
          (_) async => http.Response(
            '{"detail":"Cet email est déjà utilisé."}',
            422,
          ),
        ),
        storage: InMemorySessionStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(authService: authService)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'dup@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.textContaining('HTTP Status: 422'), findsOneWidget);
      expect(
        find.textContaining('Response: {"detail":"Cet email est déjà utilisé."}'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('RegisterScreen stops spinner after HTTP timeout', (
      WidgetTester tester,
    ) async {
      final neverCompletes = Completer<http.Response>();
      final authService = AuthService(
        client: MockClient((_) => neverCompletes.future),
        storage: InMemorySessionStorage(),
        requestTimeout: const Duration(milliseconds: 50),
      );

      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(authService: authService)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'slow@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.textContaining('timed out'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
