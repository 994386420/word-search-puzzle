import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/kid_alias_store.dart';
import 'package:word_search_puzzle/features/word_search/data/leaderboard_api.dart';
import 'package:word_search_puzzle/features/word_search/data/level_progress_store.dart';
import 'package:word_search_puzzle/features/word_search/data/star_leaderboard_service.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';
import 'package:word_search_puzzle/features/word_search/presentation/screens/leaderboard_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      KidAliasStore.aliasKey: 'SunnyStar10',
    });
  });

  testWidgets('ranking filters switch to global star progress', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final api = LeaderboardApi(
      client: MockClient((request) async => http.Response('[]', 200)),
    );
    final starService = StarLeaderboardService(
      api: api,
      progressStore: LevelProgressStore(preferences: preferences),
      aliasStore: KidAliasStore(preferences: preferences),
      preferences: preferences,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          initialCategory: wordCategories.first,
          initialDifficulty: Difficulty.easy,
          initialMode: GameMode.classic,
          api: api,
          starService: starService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Easy · Classic'), findsOneWidget);

    await tester.tap(find.byTooltip('RANKING FILTERS'));
    await tester.pumpAndSettle();

    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Stars'), findsOneWidget);
    await tester.tap(find.text('Stars'));
    await tester.pumpAndSettle();

    expect(find.text('All themes'), findsOneWidget);
    expect(find.text('0/540'), findsWidgets);
    expect(find.text('0/180 levels'), findsOneWidget);
    expect(find.text('Easy'), findsNothing);

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    expect(find.text('All themes'), findsOneWidget);
    expect(find.text('0/540'), findsOneWidget);
    expect(find.text('Easy'), findsNothing);
  });

  testWidgets('renders every rank in one compact list over the background', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final entries = List.generate(
      6,
      (index) => LeaderboardEntry(
        name: 'Player ${index + 1}',
        time: 90 + index * 8,
        score: 2400 - index * 100,
        date: DateTime(2026, 7, 20 + index),
      ),
    );
    final api = LeaderboardApi(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(entries.map((entry) => entry.toJson()).toList()),
          200,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          initialCategory: wordCategories.first,
          initialDifficulty: Difficulty.easy,
          initialMode: GameMode.classic,
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = find.byKey(const ValueKey('leaderboard-entry-1'));
    final second = find.byKey(const ValueKey('leaderboard-entry-2'));
    final fourth = find.byKey(const ValueKey('leaderboard-entry-4'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(fourth, findsOneWidget);
    expect(tester.getSize(first).height, lessThanOrEqualTo(72));
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 4'), findsOneWidget);
  });
}
