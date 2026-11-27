import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/main.dart';
import 'package:greenhouse_app/models/sensor_reading.dart';
import 'package:greenhouse_app/screens/history_screen.dart';

void main() {
  group('HistoryScreen navigation and interaction', () {
    testWidgets('navigates from Dashboard to HistoryScreen and back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const GreenHouseApp(startInDemoMode: true));

      expect(find.text('GreenHouse'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('Sensor History'), findsOneWidget);
      expect(
        find.text(
          'Simulated demo data — historical trends are illustrative only.',
        ),
        findsOneWidget,
      );
      expect(find.byType(LineChart), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('GreenHouse'), findsOneWidget);
      expect(find.text('Sensor Readings'), findsOneWidget);
    });

    testWidgets('allows switching sensors and periods and calculates summary', (
      WidgetTester tester,
    ) async {
      final sampleReadings = [
        SensorReading(
          temperature: 22.5,
          airHumidity: 55.0,
          soilMoisture: 35.0,
          lightLevel: 400.0,
          measuredAt: DateTime.utc(2026, 11, 25, 10, 0),
        ),
        SensorReading(
          temperature: 30.0,
          airHumidity: 72.0,
          soilMoisture: 48.0,
          lightLevel: 850.0,
          measuredAt: DateTime.utc(2026, 11, 25, 12, 0),
        ),
        SensorReading(
          temperature: 27.0,
          airHumidity: 64.0,
          soilMoisture: 41.0,
          lightLevel: 620.0,
          measuredAt: DateTime.utc(2026, 11, 25, 14, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(readingsLoader: (_) => sampleReadings)),
      );

      expect(find.text('Temperature (°C)'), findsOneWidget);
      expect(find.text('27.0 °C'), findsOneWidget);
      expect(find.text('22.5 °C'), findsOneWidget);
      expect(find.text('30.0 °C'), findsOneWidget);

      await tester.tap(find.text('Air Humidity'));
      await tester.pump();
      expect(find.text('Air Humidity (%)'), findsOneWidget);
      expect(find.text('64 %'), findsOneWidget);
      expect(find.text('55 %'), findsOneWidget);
      expect(find.text('72 %'), findsOneWidget);

      await tester.tap(find.text('Soil Moisture'));
      await tester.pump();
      expect(find.text('Soil Moisture (%)'), findsOneWidget);
      expect(find.text('41 %'), findsOneWidget);
      expect(find.text('35 %'), findsOneWidget);
      expect(find.text('48 %'), findsOneWidget);

      await tester.tap(find.text('Light Level'));
      await tester.pump();
      expect(find.text('Light Level (lux)'), findsOneWidget);
      expect(find.text('620 lux'), findsOneWidget);
      expect(find.text('400 lux'), findsOneWidget);
      expect(find.text('850 lux'), findsOneWidget);

      await tester.tap(find.text('Last 7 days'));
      await tester.pump();
      expect(find.text('Last 7 days'), findsNWidgets(3));

      await tester.tap(find.text('Last 30 days'));
      await tester.pump();
      expect(find.text('Last 30 days'), findsNWidgets(3));
    });

    testWidgets('shows empty state when no historical data exists', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(readingsLoader: (_) => const [])),
      );

      expect(
        find.text('No historical data available for this period.'),
        findsOneWidget,
      );
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('--'), findsNWidgets(3));
    });
  });
}
