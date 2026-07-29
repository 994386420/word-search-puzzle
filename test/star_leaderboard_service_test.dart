import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/kid_alias_store.dart';
import 'package:word_search_puzzle/features/word_search/data/leaderboard_api.dart';
import 'package:word_search_puzzle/features/word_search/data/level_progress_store.dart';
import 'package:word_search_puzzle/features/word_search/data/star_leaderboard_service.dart';
import 'package:word_search_puzzle/features/word_search/domain/level_progression.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      KidAliasStore.aliasKey: 'SunnyStar10',
    });
  });

  test('syncs unique best stars and skips duplicate submissions', () async {
    final preferences = await SharedPreferences.getInstance();
    final progressStore = LevelProgressStore(preferences: preferences);
    final first = firstCampaignLevel();
    final second = nextCampaignLevel(first)!;
    await progressStore.recordCompleted(first, stars: 2, elapsedSeconds: 70);
    await progressStore.recordCompleted(second, stars: 3, elapsedSeconds: 50);
    var postCount = 0;
    var getCount = 0;
    Map<String, dynamic>? submittedBody;
    final api = LeaderboardApi(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          postCount += 1;
          submittedBody = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(
            jsonEncode({
              'rank': 1,
              'entries': [
                {
                  'name': 'SunnyStar10',
                  'time': 120,
                  'score': 5,
                  'date': '2026-07-20T00:00:00.000Z',
                },
                {
                  'name': 'SunnyStar10',
                  'time': 100,
                  'score': 4,
                  'date': '2026-07-19T00:00:00.000Z',
                },
                {
                  'name': 'BrightPanda22',
                  'time': 100,
                  'score': 4,
                  'date': '2026-07-18T00:00:00.000Z',
                },
                {
                  'name': 'unsafe-name',
                  'time': 1,
                  'score': 540,
                  'date': '2026-07-17T00:00:00.000Z',
                },
              ],
            }),
            200,
          );
        }
        getCount += 1;
        return http.Response('[]', 200);
      }),
    );
    final service = StarLeaderboardService(
      api: api,
      progressStore: progressStore,
      aliasStore: KidAliasStore(preferences: preferences),
      preferences: preferences,
    );

    final firstLoad = await service.loadAndSync();
    final secondLoad = await service.loadAndSync();

    expect(firstLoad.totalStars, 5);
    expect(firstLoad.completedLevels, 2);
    expect(firstLoad.totalBestSeconds, 120);
    expect(firstLoad.entries, hasLength(2));
    expect(firstLoad.entries.first.name, 'SunnyStar10');
    expect(firstLoad.entries.first.score, 5);
    expect(secondLoad.totalStars, 5);
    expect(postCount, 1);
    expect(getCount, 1);
    expect(submittedBody, {'name': 'SunnyStar10', 'time': 120, 'score': 5});
  });

  test('submits again when a level gains another star', () async {
    final preferences = await SharedPreferences.getInstance();
    final progressStore = LevelProgressStore(preferences: preferences);
    final level = firstCampaignLevel();
    await progressStore.recordCompleted(level, stars: 2, elapsedSeconds: 70);
    var postCount = 0;
    final api = LeaderboardApi(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          postCount += 1;
          return http.Response(
            jsonEncode({'rank': 1, 'entries': <Object>[]}),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    final service = StarLeaderboardService(
      api: api,
      progressStore: progressStore,
      aliasStore: KidAliasStore(preferences: preferences),
      preferences: preferences,
    );
    await service.loadAndSync();
    await progressStore.recordCompleted(level, stars: 3, elapsedSeconds: 60);

    final improved = await service.loadAndSync();

    expect(improved.totalStars, 3);
    expect(improved.totalBestSeconds, 60);
    expect(postCount, 2);
  });
}
