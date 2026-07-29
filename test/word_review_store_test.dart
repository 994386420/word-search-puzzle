import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/word_review_store.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('records first found word', () async {
    const store = WordReviewStore();
    final category = wordCategories.first;
    final now = DateTime(2026, 7, 13, 10);

    await store.recordFound(word: 'lion', category: category, now: now);

    final records = await store.getRecords();
    expect(records, hasLength(1));
    expect(records.first.word, 'LION');
    expect(records.first.categoryId, category.id);
    expect(records.first.timesFound, 1);
    expect(records.first.firstSeenAt, now);
    expect(records.first.lastSeenAt, now);
    expect(records.first.isFavorite, isFalse);
    expect(records.first.masteryLevel, 1);
    expect(records.first.nextReviewAt, now.add(const Duration(days: 1)));
  });

  test('assisted finds lower mastery and become due sooner', () async {
    const store = WordReviewStore();
    final category = wordCategories.first;
    final firstSeen = DateTime(2026, 7, 13, 10);

    await store.recordFound(word: 'LION', category: category, now: firstSeen);
    await store.recordFound(
      word: 'LION',
      category: category,
      now: firstSeen.add(const Duration(hours: 1)),
      assisted: true,
    );

    final record = await store.getRecord('LION');
    expect(record?.masteryLevel, 0);
    final due = await store.getDueRecords(
      now: firstSeen.add(const Duration(days: 2)),
    );
    expect(due.map((item) => item.word), contains('LION'));
  });

  test('increments times found and preserves first seen time', () async {
    const store = WordReviewStore();
    final category = wordCategories.first;
    final firstSeen = DateTime(2026, 7, 13, 10);
    final lastSeen = DateTime(2026, 7, 13, 11);

    await store.recordFound(word: 'LION', category: category, now: firstSeen);
    await store.recordFound(word: 'lion', category: category, now: lastSeen);

    final record = await store.getRecord('lion');
    expect(record, isNotNull);
    expect(record!.timesFound, 2);
    expect(record.firstSeenAt, firstSeen);
    expect(record.lastSeenAt, lastSeen);
  });

  test('toggles favorite state', () async {
    const store = WordReviewStore();
    final category = wordCategories.first;

    await store.recordFound(word: 'LION', category: category);

    final favorited = await store.toggleFavorite('lion');
    final first = await store.getRecord('LION');
    final unfavorited = await store.toggleFavorite('LION');
    final second = await store.getRecord('LION');

    expect(favorited, isTrue);
    expect(first?.isFavorite, isTrue);
    expect(unfavorited, isFalse);
    expect(second?.isFavorite, isFalse);
  });

  test('handles corrupt stored json gracefully', () async {
    SharedPreferences.setMockInitialValues({
      WordReviewStore.recordsKey: '{bad json',
    });
    const store = WordReviewStore();

    final records = await store.getRecords();

    expect(records, isEmpty);
  });

  test('migrates legacy words and repairs stale category ids', () async {
    final legacyCavern = _record(
      word: 'CAVERN',
      categoryId: 'animals',
      lastSeenAt: DateTime(2026, 7, 13),
    );
    final misplacedLion = _record(
      word: 'LION',
      categoryId: 'food',
      lastSeenAt: DateTime(2026, 7, 14),
      isFavorite: true,
      timesFound: 3,
    );
    final techCloud = _record(
      word: 'CLOUD',
      categoryId: 'tech',
      lastSeenAt: DateTime(2026, 7, 15),
    );
    SharedPreferences.setMockInitialValues({
      WordReviewStore.recordsKey: jsonEncode([
        legacyCavern.toJson(),
        misplacedLion.toJson(),
        techCloud.toJson(),
      ]),
    });
    const store = WordReviewStore();

    final records = await store.getRecords();

    expect(records.map((record) => record.word), ['CLOUD', 'LION']);
    expect(records.first.categoryId, 'tech');
    expect(records.last.categoryId, 'animals');
    expect(records.last.isFavorite, isTrue);
    expect(records.last.timesFound, 3);

    final preferences = await SharedPreferences.getInstance();
    final migratedJson = preferences.getString(WordReviewStore.recordsKey)!;
    expect(migratedJson, isNot(contains('CAVERN')));
    expect(migratedJson, contains('"categoryId":"animals"'));
  });

  test('does not add words outside the active curriculum', () async {
    const store = WordReviewStore();
    final category = wordCategories.first;

    await store.recordFound(word: 'CAVERN', category: category);
    await store.setFavorite(
      word: 'DRAGON',
      categoryId: category.id,
      isFavorite: true,
    );

    expect(await store.getRecords(), isEmpty);
  });
}

LearnedWordRecord _record({
  required String word,
  required String categoryId,
  required DateTime lastSeenAt,
  bool isFavorite = false,
  int timesFound = 1,
}) {
  return LearnedWordRecord(
    word: word,
    categoryId: categoryId,
    timesFound: timesFound,
    firstSeenAt: lastSeenAt,
    lastSeenAt: lastSeenAt,
    isFavorite: isFavorite,
    masteryLevel: 1,
    nextReviewAt: lastSeenAt.add(const Duration(days: 1)),
  );
}
