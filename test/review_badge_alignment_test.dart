import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/word_review_store.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/presentation/screens/kids_hub_screen.dart';

void main() {
  testWidgets('review badge does not shift the header icon', (tester) async {
    final now = DateTime(2026, 7, 28);
    final records = wordCategories.first.words
        .take(8)
        .map(
          (word) => LearnedWordRecord(
            word: word,
            categoryId: wordCategories.first.id,
            timesFound: 1,
            firstSeenAt: now,
            lastSeenAt: now,
            isFavorite: false,
            masteryLevel: 1,
            nextReviewAt: now.subtract(const Duration(days: 1)),
          ).toJson(),
        );
    SharedPreferences.setMockInitialValues({
      WordReviewStore.recordsKey: jsonEncode(records.toList()),
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: KidsHubScreen(
          onStartLevel: (_) async {},
          onStart: (_, _, _, _) {},
        ),
      ),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('8').evaluate().isNotEmpty) {
        break;
      }
    }

    final buttonCenter = tester.getCenter(
      find.byKey(const ValueKey('review-button')),
    );
    final iconCenter = tester.getCenter(
      find.byKey(const ValueKey('review-button-icon')),
    );
    expect(find.text('8'), findsOneWidget);
    expect(iconCenter.dx, closeTo(buttonCenter.dx, 0.01));
    expect(iconCenter.dy, closeTo(buttonCenter.dy, 0.01));
    expect(tester.takeException(), isNull);
  });
}
