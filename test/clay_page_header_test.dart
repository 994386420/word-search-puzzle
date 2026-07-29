import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_search_puzzle/features/word_search/presentation/widgets/clay_ui.dart';

void main() {
  testWidgets('clay page header stays usable across phone widths', (
    tester,
  ) async {
    for (final size in const [Size(320, 568), Size(360, 800), Size(430, 932)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClayPageHeader(
                  title: 'DAILY CHALLENGE',
                  subtitle: 'See, hear, and find every word',
                  onBack: () {},
                  onAction: () {},
                  actionIcon: Icons.refresh_rounded,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('DAILY CHALLENGE'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
