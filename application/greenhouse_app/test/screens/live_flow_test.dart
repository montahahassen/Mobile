import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/main.dart';
import 'package:greenhouse_app/services/auth_service.dart';
import 'package:greenhouse_app/services/session_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Live API end-to-end UI flow', () {
    testWidgets('logs in, displays live Dashboard data, and opens History', (
      WidgetTester tester,
    ) async {
      final now = DateTime.now().toUtc();
      final t1 = now.subtract(const Duration(hours: 2)).toIso8601String();
      final t2 = now.subtract(const Duration(minutes: 5)).toIso8601String();

      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth') {
          return http.Response(
            jsonEncode({
              'token': 'live-jwt',
              'id': 2,
              'firstname': 'Atef',
              'lastname': 'B',
              'email': 'atef@example.com',
            }),
            200,
          );
        }

        if (request.url.path == '/api/devices') {
          return http.Response(
            jsonEncode({
              '@type': 'Collection',
              'member': [
                {
                  'id': 1,
                  'name': 'Serre Nord',
                  'location': 'Tunis',
                  'isActive': true,
                  'owner': '/api/users/2',
                },
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/sensors') {
          return http.Response(
            jsonEncode({
              '@type': 'Collection',
              'member': [
                {'id': 10, 'type': 'temperature', 'unit': '°C', 'device': '/api/devices/1'},
                {'id': 11, 'type': 'air_humidity', 'unit': '%', 'device': '/api/devices/1'},
                {'id': 12, 'type': 'soil_moisture', 'unit': '%', 'device': '/api/devices/1'},
                {'id': 13, 'type': 'light_level', 'unit': 'lux', 'device': '/api/devices/1'},
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/measurements') {
          return http.Response(
            jsonEncode({
              '@type': 'Collection',
              'member': [
                {'id': 1, 'value': 24.0, 'measuredAt': t1, 'sensor': '/api/sensors/10'},
                {'id': 2, 'value': 27.4, 'measuredAt': t2, 'sensor': '/api/sensors/10'},
                {'id': 3, 'value': 61.0, 'measuredAt': t2, 'sensor': '/api/sensors/11'},
                {'id': 4, 'value': 45.0, 'measuredAt': t2, 'sensor': '/api/sensors/12'},
                {'id': 5, 'value': 680.0, 'measuredAt': t2, 'sensor': '/api/sensors/13'},
              ],
            }),
            200,
          );
        }

        return http.Response('Not found', 404);
      });

      final authService = AuthService(
        client: mockClient,
        storage: InMemorySessionStorage(),
      );

      await tester.pumpWidget(
        GreenHouseApp(authService: authService, httpClient: mockClient),
      );
      await tester.pumpAndSettle();

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

      expect(find.text('Welcome back, Atef B!'), findsOneWidget);
      expect(find.text('Serre Nord'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('27.4'), findsOneWidget);
      expect(find.text('61'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('680'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('Live backend history — Serre Nord'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('24.0 °C'), findsOneWidget);
      expect(find.text('27.4 °C'), findsNWidgets(2));
    });

    testWidgets('redirects to LoginScreen on HTTP 401 unauthorized', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth') {
          return http.Response(
            jsonEncode({
              'token': 'expired-jwt',
              'id': 2,
              'firstname': 'Atef',
              'lastname': 'B',
              'email': 'atef@example.com',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'code': 401, 'message': 'Expired JWT Token'}),
          401,
        );
      });

      final authService = AuthService(
        client: mockClient,
        storage: InMemorySessionStorage(),
      );

      await tester.pumpWidget(
        GreenHouseApp(authService: authService, httpClient: mockClient),
      );
      await tester.pumpAndSettle();

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

      expect(find.text('Continue in Demo Mode'), findsOneWidget);
      expect(
        find.text('Session expired. Please sign in again.'),
        findsOneWidget,
      );
    });
  });
}
