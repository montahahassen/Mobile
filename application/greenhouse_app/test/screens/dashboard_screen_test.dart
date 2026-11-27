import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/screens/dashboard_screen.dart';

void main() {
  group('DashboardScreen live monitoring', () {
    testWidgets(
      'updates temperature and timestamp every 5 seconds while keeping other sensors constant',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DashboardScreen(nowProvider: tester.binding.clock.now),
          ),
        );

        // Initial values at t = 0s
        expect(find.text('28.5'), findsOneWidget);
        expect(find.text('65'), findsOneWidget);
        expect(find.text('40'), findsOneWidget);
        expect(find.text('750'), findsOneWidget);

        final initialLastUpdateWidget = tester.widget<Text>(
          find.textContaining('Last update: Simulated live · '),
        );
        final initialLastUpdateText = initialLastUpdateWidget.data!;

        // Advance simulated time by 5 seconds and check updated values
        String previousTimestamp = initialLastUpdateText;
        for (var tick = 1; tick <= 6; tick++) {
          await tester.pump(const Duration(seconds: 5));

          if (tick == 1) {
            expect(find.text('28.5'), findsNothing);
          }

          // Verify temperature card value stays within [27.0, 30.0]
          final tempCard = tester.widget<Text>(
            find.descendant(
              of: find
                  .ancestor(
                    of: find.text('Temperature'),
                    matching: find.byType(Container),
                  )
                  .first,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Text &&
                    widget.style?.fontSize == 27 &&
                    widget.data != null,
              ),
            ),
          );
          final parsedTemp = double.parse(tempCard.data!);
          expect(parsedTemp, inInclusiveRange(27.0, 30.0));

          // Other three sensors remain constant
          expect(find.text('65'), findsOneWidget);
          expect(find.text('40'), findsOneWidget);
          expect(find.text('750'), findsOneWidget);

          // Timestamp updates on every 5-second interval
          final currentLastUpdateText = tester
              .widget<Text>(
                find.textContaining('Last update: Simulated live · '),
              )
              .data!;
          expect(currentLastUpdateText, isNot(previousTimestamp));
          previousTimestamp = currentLastUpdateText;
        }

        // Verify timer is cancelled cleanly on dispose
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pump(const Duration(seconds: 10));
      },
    );
  });
}
