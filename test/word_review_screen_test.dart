import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/word_review_store.dart';
import 'package:word_search_puzzle/features/word_search/presentation/screens/word_review_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'word_search_review_voice_guide_seen': true,
    });
  });

  testWidgets('stops voice and returns without trapping navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WordReviewScreen(),
                ),
              ),
              child: const Text('Open review'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    expect(find.byType(WordReviewScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(WordReviewScreen), findsNothing);
    expect(find.text('Open review'), findsOneWidget);
  });

  testWidgets('opens an illustrated word card and saves the favorite', (
    tester,
  ) async {
    final record = LearnedWordRecord(
      word: 'LION',
      categoryId: 'animals',
      timesFound: 2,
      firstSeenAt: DateTime(2026, 7, 10),
      lastSeenAt: DateTime(2026, 7, 15),
      isFavorite: false,
      masteryLevel: 2,
      nextReviewAt: DateTime(2026, 7, 16),
    );
    SharedPreferences.setMockInitialValues({
      'word_search_review_voice_guide_seen': true,
      WordReviewStore.recordsKey: jsonEncode([record.toJson()]),
    });

    await tester.pumpWidget(const MaterialApp(home: WordReviewScreen()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('review-word-image-LION')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('review-word-tile-LION')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('word-detail-LION')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('word-detail-image-LION')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('word-detail-audio-LION')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('word-detail-favorite-LION')));
    await tester.pumpAndSettle();

    final savedRecord = await const WordReviewStore().getRecord('LION');
    expect(savedRecord?.isFavorite, isTrue);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('word-detail-LION')), findsNothing);
  });

  testWidgets('keeps the word list visible while refresh is pending', (
    tester,
  ) async {
    final lion = _record('LION');
    final panda = _record('PANDA');
    final store = _ControlledWordReviewStore([lion]);

    await tester.pumpWidget(MaterialApp(home: WordReviewScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('LION'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();

    expect(find.text('LION'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    store.refreshCompleter.complete([panda]);
    await tester.pumpAndSettle();

    expect(find.text('LION'), findsNothing);
    expect(find.text('PANDA'), findsOneWidget);
  });

  testWidgets('removes legacy review words before rendering the list', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 15);
    final records = [
      LearnedWordRecord(
        word: 'CAVERN',
        categoryId: 'animals',
        timesFound: 1,
        firstSeenAt: now,
        lastSeenAt: now,
        isFavorite: false,
        masteryLevel: 1,
        nextReviewAt: now,
      ),
      LearnedWordRecord(
        word: 'LION',
        categoryId: 'animals',
        timesFound: 1,
        firstSeenAt: now,
        lastSeenAt: now,
        isFavorite: false,
        masteryLevel: 1,
        nextReviewAt: now,
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'word_search_review_voice_guide_seen': true,
      WordReviewStore.recordsKey: jsonEncode(
        records.map((record) => record.toJson()).toList(),
      ),
    });

    await tester.pumpWidget(const MaterialApp(home: WordReviewScreen()));
    await tester.pumpAndSettle();

    expect(find.text('CAVERN'), findsNothing);
    expect(find.text('LION'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('review-word-image-LION')),
      findsOneWidget,
    );
  });

  testWidgets('shows expanded words with their bundled illustration', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 15);
    final record = LearnedWordRecord(
      word: 'GORILLA',
      categoryId: 'animals',
      timesFound: 1,
      firstSeenAt: now,
      lastSeenAt: now,
      isFavorite: false,
      masteryLevel: 1,
      nextReviewAt: now,
    );
    SharedPreferences.setMockInitialValues({
      'word_search_review_voice_guide_seen': true,
      WordReviewStore.recordsKey: jsonEncode([record.toJson()]),
    });

    await tester.pumpWidget(const MaterialApp(home: WordReviewScreen()));
    await tester.pumpAndSettle();

    expect(find.text('GORILLA'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('review-word-image-GORILLA')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.image_outlined), findsNothing);
  });
}

LearnedWordRecord _record(String word) {
  final now = DateTime(2026, 7, 15);
  return LearnedWordRecord(
    word: word,
    categoryId: 'animals',
    timesFound: 1,
    firstSeenAt: now,
    lastSeenAt: now,
    isFavorite: false,
    masteryLevel: 1,
    nextReviewAt: now,
  );
}

class _ControlledWordReviewStore extends WordReviewStore {
  _ControlledWordReviewStore(this.initialRecords);

  final List<LearnedWordRecord> initialRecords;
  final refreshCompleter = Completer<List<LearnedWordRecord>>();
  var _loadCount = 0;

  @override
  Future<List<LearnedWordRecord>> getRecords() {
    _loadCount++;
    if (_loadCount == 1) {
      return Future.value(initialRecords);
    }
    return refreshCompleter.future;
  }
}
