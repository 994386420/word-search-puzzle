import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

class LeaderboardApi {
  LeaderboardApi({http.Client? client}) : _client = client ?? http.Client();

  static const _projectId = 'dwxjiptmigtlllhylolm';
  static const _publicAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR3eGppcHRtaWd0bGxsaHlsb2xtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwNTUzNjIsImV4cCI6MjA5ODYzMTM2Mn0.czLaWk6AN8t7F9parLt-JyfidUU65wAYj3tT6j_T__I';
  static const _base =
      'https://$_projectId.supabase.co/functions/v1/make-server-e61dd5d6';
  // Bump this namespace whenever the public leaderboard needs a clean reset.
  static const _leaderboardNamespace = 'season2';

  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  Future<List<LeaderboardEntry>> fetchLeaderboard(
    String mode,
    String categoryId,
    String difficulty,
  ) async {
    return _fetchByCategoryKey(_modeCategoryKey(mode, categoryId), difficulty);
  }

  Future<List<LeaderboardEntry>> _fetchByCategoryKey(
    String categoryKey,
    String difficulty,
  ) async {
    final response = await _send(
      () => _client.get(
        Uri.parse('$_base/leaderboard/$categoryKey/$difficulty'),
        headers: _headers,
      ),
      action: 'load leaderboard',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LeaderboardException(
        'Could not load leaderboard (HTTP ${response.statusCode})',
      );
    }
    final decoded = _decodeJson(response.body);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList(growable: false);
  }

  Future<ScoreSubmissionResult> submitScore({
    required String mode,
    required String categoryId,
    required String difficulty,
    required String name,
    required int time,
    required int score,
  }) async {
    final response = await _send(
      () => _client.post(
        Uri.parse(
          '$_base/leaderboard/${_modeCategoryKey(mode, categoryId)}/$difficulty',
        ),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'time': time, 'score': score}),
      ),
      action: 'submit score',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = _tryDecodeJson(response.body);
      final error = decoded is Map ? decoded['error'] : null;
      throw LeaderboardException(
        (error ?? 'Could not submit score (HTTP ${response.statusCode})')
            .toString(),
      );
    }
    final decoded = _decodeJson(response.body);
    final entriesRaw = decoded is Map ? decoded['entries'] : null;
    final entries = entriesRaw is List
        ? entriesRaw
              .whereType<Map<String, dynamic>>()
              .map(LeaderboardEntry.fromJson)
              .toList(growable: false)
        : <LeaderboardEntry>[];
    return ScoreSubmissionResult(
      rank: decoded is Map && decoded['rank'] is num
          ? (decoded['rank'] as num).toInt()
          : 0,
      entries: entries,
    );
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_publicAnonKey',
  };

  String _modeCategoryKey(String mode, String categoryId) {
    return '${_leaderboardNamespace}_${mode}_$categoryId';
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required String action,
  }) async {
    try {
      return await request().timeout(_timeout);
    } on LeaderboardException {
      rethrow;
    } catch (error) {
      throw LeaderboardException('Could not $action. Check your connection.');
    }
  }

  dynamic _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      throw LeaderboardException('Leaderboard returned an invalid response.');
    }
  }

  dynamic _tryDecodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}

class LeaderboardException implements Exception {
  const LeaderboardException(this.message);

  final String message;

  @override
  String toString() => message;
}
