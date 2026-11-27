import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/main.dart';
import 'package:greenhouse_app/services/auth_service.dart';
import 'package:greenhouse_app/services/session_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('GreenHouse opens LoginScreen and supports Demo Mode', (
    WidgetTester tester,
  ) async {
    final authService = AuthService(
      client: MockClient((_) async => http.Response('{}', 200)),
      storage: InMemorySessionStorage(),
    );

    await tester.pumpWidget(GreenHouseApp(authService: authService));
    await tester.pumpAndSettle();

    expect(find.text('GreenHouse'), findsOneWidget);
    expect(find.text('Continue in Demo Mode'), findsOneWidget);

    await tester.tap(find.text('Continue in Demo Mode'));
    await tester.pump();

    expect(find.text('Sensor Readings'), findsOneWidget);
  });
}
