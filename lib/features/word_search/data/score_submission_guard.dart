import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

class ScoreSubmissionGuard {
  ScoreSubmissionGuard({SharedPreferences? preferences})
    : _preferences = preferences;

  static const cooldown = Duration(seconds: 10);
  static const _lastSubmitPrefix = 'leaderboard_last_submit';

  final SharedPreferences? _preferences;

  Future<ValidatedScoreSubmission> prepare({
    required WordCategory category,
    required Difficulty difficulty,
    required GameMode mode,
    required String name,
    required int time,
    required int score,
    required int maxScore,
  }) async {
    final normalizedName = _normalizeName(name);
    _validateName(normalizedName);
    _validateScore(mode: mode, time: time, score: score, maxScore: maxScore);
    await _enforceCooldown(category, difficulty, mode);
    return ValidatedScoreSubmission(
      name: normalizedName,
      time: time,
      score: score,
    );
  }

  Future<void> markSubmitted({
    required WordCategory category,
    required Difficulty difficulty,
    required GameMode mode,
  }) async {
    final prefs = await _getPreferences();
    await prefs.setInt(
      _submitKey(category, difficulty, mode),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _enforceCooldown(
    WordCategory category,
    Difficulty difficulty,
    GameMode mode,
  ) async {
    final prefs = await _getPreferences();
    final lastSubmitMs = prefs.getInt(_submitKey(category, difficulty, mode));
    if (lastSubmitMs == null) {
      return;
    }
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastSubmitMs),
    );
    if (elapsed < cooldown) {
      final remaining = cooldown.inSeconds - elapsed.inSeconds;
      throw ScoreSubmissionException(
        'Please wait ${remaining.clamp(1, cooldown.inSeconds)}s before submitting again.',
      );
    }
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  static String _normalizeName(String name) {
    return name
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static void _validateName(String name) {
    if (name.isEmpty) {
      throw const ScoreSubmissionException('Enter a name to save your score.');
    }
    if (name.length > 20) {
      throw const ScoreSubmissionException(
        'Name must be 20 characters or less.',
      );
    }
    if (RegExp(r'[<>{}\[\]\\|]').hasMatch(name)) {
      throw const ScoreSubmissionException(
        'Name contains unsupported characters.',
      );
    }
  }

  static void _validateScore({
    required GameMode mode,
    required int time,
    required int score,
    required int maxScore,
  }) {
    if (score < 0 || score > maxScore) {
      throw const ScoreSubmissionException('Score could not be verified.');
    }
    if (mode == GameMode.classic && score != maxScore) {
      throw const ScoreSubmissionException('Classic score is incomplete.');
    }
    if (mode == GameMode.speed && time > GameControllerLimits.speedSeconds) {
      throw const ScoreSubmissionException('Speed round time is invalid.');
    }
    if (time < 0 || (mode == GameMode.classic && time == 0)) {
      throw const ScoreSubmissionException('Time could not be verified.');
    }
  }

  static String _submitKey(
    WordCategory category,
    Difficulty difficulty,
    GameMode mode,
  ) {
    return '$_lastSubmitPrefix.${mode.storageName}.${category.id}.${difficulty.storageName}';
  }
}

class GameControllerLimits {
  const GameControllerLimits._();

  static const speedSeconds = 120;
}

class ValidatedScoreSubmission {
  const ValidatedScoreSubmission({
    required this.name,
    required this.time,
    required this.score,
  });

  final String name;
  final int time;
  final int score;
}

class ScoreSubmissionException implements Exception {
  const ScoreSubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}
