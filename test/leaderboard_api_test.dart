import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:word_search_puzzle/features/word_search/data/leaderboard_api.dart';

void main() {
  group('LeaderboardApi', () {
    test(
      'classic leaderboard uses reset namespace without legacy fallback',
      () async {
        final requestedPaths = <String>[];
        final api = LeaderboardApi(
          client: MockClient((request) async {
            requestedPaths.add(request.url.path);
            if (request.url.path.endsWith(
              '/leaderboard/season2_classic_animals/easy',
            )) {
              return http.Response('[]', 200);
            }
            if (request.url.path.endsWith('/leaderboard/animals/easy')) {
              return http.Response(
                jsonEncode([
                  {
                    'name': 'OLD',
                    'time': 91,
                    'score': 400,
                    'date': '2026-07-01T00:00:00.000Z',
                  },
                ]),
                200,
              );
            }
            return http.Response('[]', 404);
          }),
        );

        final entries = await api.fetchLeaderboard(
          'classic',
          'animals',
          'easy',
        );

        expect(entries, isEmpty);
        expect(requestedPaths, [
          '/functions/v1/make-server-e61dd5d6/leaderboard/season2_classic_animals/easy',
        ]);
      },
    );

    test(
      'classic leaderboard keeps mode-separated records when present',
      () async {
        final requestedPaths = <String>[];
        final api = LeaderboardApi(
          client: MockClient((request) async {
            requestedPaths.add(request.url.path);
            return http.Response(
              jsonEncode([
                {
                  'name': 'NEW',
                  'time': 54,
                  'score': 700,
                  'date': '2026-07-02T00:00:00.000Z',
                },
              ]),
              200,
            );
          }),
        );

        final entries = await api.fetchLeaderboard(
          'classic',
          'animals',
          'easy',
        );

        expect(entries, hasLength(1));
        expect(entries.single.name, 'NEW');
        expect(requestedPaths, [
          '/functions/v1/make-server-e61dd5d6/leaderboard/season2_classic_animals/easy',
        ]);
      },
    );

    test(
      'speed leaderboard does not fall back to legacy classic records',
      () async {
        final requestedPaths = <String>[];
        final api = LeaderboardApi(
          client: MockClient((request) async {
            requestedPaths.add(request.url.path);
            return http.Response('[]', 200);
          }),
        );

        final entries = await api.fetchLeaderboard('speed', 'animals', 'easy');

        expect(entries, isEmpty);
        expect(requestedPaths, [
          '/functions/v1/make-server-e61dd5d6/leaderboard/season2_speed_animals/easy',
        ]);
      },
    );

    test('star leaderboard uses one global campaign board', () async {
      late http.Request submittedRequest;
      final api = LeaderboardApi(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            submittedRequest = request;
            return http.Response(
              jsonEncode({'rank': 1, 'entries': <Object>[]}),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
      );

      await api.fetchLeaderboard('stars', 'all', 'campaign');
      await api.submitScore(
        mode: 'stars',
        categoryId: 'all',
        difficulty: 'campaign',
        name: 'SunnyStar10',
        time: 125,
        score: 7,
      );

      expect(
        submittedRequest.url.path,
        '/functions/v1/make-server-e61dd5d6/leaderboard/season2_stars_all/campaign',
      );
      expect(jsonDecode(submittedRequest.body), {
        'name': 'SunnyStar10',
        'time': 125,
        'score': 7,
      });
    });
  });
}
