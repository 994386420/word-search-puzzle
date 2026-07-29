import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/app/app_theme.dart';
import 'package:word_search_puzzle/features/word_search/data/appearance_preference_store.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';
import 'package:word_search_puzzle/features/word_search/presentation/controllers/game_controller.dart';
import 'package:word_search_puzzle/features/word_search/presentation/screens/game_screen.dart';
import 'package:word_search_puzzle/l10n/app_strings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('win dialog keeps its primary actions usable on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GameController(
      category: wordCategories.first,
      difficulty: Difficulty.easy,
      mode: GameMode.classic,
      random: Random(51),
    );
    await controller.start();
    for (final placement in controller.placements.toList(growable: false)) {
      await controller.markFound(placement);
    }
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: WordSearchAppTheme.light(AppSkin.fresh),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: WinDialog(
            controller: controller,
            onBack: () {},
            onLeaderboard: () {},
            isDailyChallenge: false,
            onNextPuzzle: (_, _, _, _) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('Round details'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Round details'));
    await tester.pumpAndSettle();

    expect(find.text('Score & leaderboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
