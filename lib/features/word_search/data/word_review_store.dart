import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/categories.dart';
import '../domain/models.dart';

class LearnedWordRecord {
  const LearnedWordRecord({
    required this.word,
    required this.categoryId,
    required this.timesFound,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.isFavorite,
    required this.masteryLevel,
    required this.nextReviewAt,
  });

  final String word;
  final String categoryId;
  final int timesFound;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final bool isFavorite;
  final int masteryLevel;
  final DateTime nextReviewAt;

  bool isDueAt(DateTime now) => !nextReviewAt.isAfter(now);

  LearnedWordRecord copyWith({
    String? categoryId,
    int? timesFound,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    bool? isFavorite,
    int? masteryLevel,
    DateTime? nextReviewAt,
  }) {
    return LearnedWordRecord(
      word: word,
      categoryId: categoryId ?? this.categoryId,
      timesFound: timesFound ?? this.timesFound,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isFavorite: isFavorite ?? this.isFavorite,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'categoryId': categoryId,
    'timesFound': timesFound,
    'firstSeenAt': firstSeenAt.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(),
    'isFavorite': isFavorite,
    'masteryLevel': masteryLevel,
    'nextReviewAt': nextReviewAt.toIso8601String(),
  };

  static LearnedWordRecord? fromJson(Map<String, dynamic> json) {
    final word = _normalizeWord(json['word']?.toString() ?? '');
    if (word.isEmpty) {
      return null;
    }
    final firstSeenAt =
        DateTime.tryParse(json['firstSeenAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final lastSeenAt =
        DateTime.tryParse(json['lastSeenAt']?.toString() ?? '') ?? firstSeenAt;
    return LearnedWordRecord(
      word: word,
      categoryId: json['categoryId']?.toString() ?? '',
      timesFound: ((json['timesFound'] as num?)?.toInt() ?? 0)
          .clamp(0, 9999)
          .toInt(),
      firstSeenAt: firstSeenAt,
      lastSeenAt: lastSeenAt,
      isFavorite: json['isFavorite'] == true,
      masteryLevel: ((json['masteryLevel'] as num?)?.toInt() ?? 0)
          .clamp(0, 5)
          .toInt(),
      nextReviewAt:
          DateTime.tryParse(json['nextReviewAt']?.toString() ?? '') ??
          lastSeenAt,
    );
  }
}

class WordReviewStore {
  const WordReviewStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const recordsKey = 'word_review_records_v1';

  final SharedPreferences? _preferences;

  Future<List<LearnedWordRecord>> getRecords() async {
    final prefs = await _getPreferences();
    final decodedRecords = _decodeRecords(prefs.getString(recordsKey));
    final records = <LearnedWordRecord>[];
    var migrated = false;
    for (final record in decodedRecords) {
      final activeCategoryId = _activeCategoryIdFor(
        record.word,
        preferredCategoryId: record.categoryId,
      );
      if (activeCategoryId == null) {
        migrated = true;
        continue;
      }
      if (activeCategoryId != record.categoryId) {
        migrated = true;
        records.add(record.copyWith(categoryId: activeCategoryId));
      } else {
        records.add(record);
      }
    }
    records.sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    if (migrated) {
      await _writeRecords(prefs, records);
    }
    return records;
  }

  Future<LearnedWordRecord?> getRecord(String word) async {
    final normalized = _normalizeWord(word);
    if (normalized.isEmpty) {
      return null;
    }
    final records = await getRecords();
    for (final record in records) {
      if (record.word == normalized) {
        return record;
      }
    }
    return null;
  }

  Future<List<LearnedWordRecord>> getDueRecords({DateTime? now}) async {
    final checkTime = now ?? DateTime.now();
    final records = (await getRecords())
        .where((record) => record.isDueAt(checkTime))
        .toList(growable: false);
    records.sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
    return records;
  }

  Future<void> recordFound({
    required String word,
    required WordCategory category,
    DateTime? now,
    bool assisted = false,
  }) async {
    final normalized = _normalizeWord(word);
    if (normalized.isEmpty) {
      return;
    }
    final activeCategoryId = _activeCategoryIdFor(
      normalized,
      preferredCategoryId: category.id,
    );
    if (activeCategoryId == null) {
      return;
    }
    final currentTime = now ?? DateTime.now();
    final records = await getRecords();
    final index = records.indexWhere((record) => record.word == normalized);
    if (index < 0) {
      records.add(
        LearnedWordRecord(
          word: normalized,
          categoryId: activeCategoryId,
          timesFound: 1,
          firstSeenAt: currentTime,
          lastSeenAt: currentTime,
          isFavorite: false,
          masteryLevel: assisted ? 0 : 1,
          nextReviewAt: currentTime.add(const Duration(days: 1)),
        ),
      );
    } else {
      final existing = records[index];
      final nextMastery = assisted
          ? (existing.masteryLevel - 1).clamp(0, 5).toInt()
          : (existing.masteryLevel + 1).clamp(0, 5).toInt();
      records[index] = existing.copyWith(
        categoryId: existing.categoryId.isEmpty
            ? category.id
            : existing.categoryId,
        timesFound: existing.timesFound + 1,
        lastSeenAt: currentTime,
        masteryLevel: nextMastery,
        nextReviewAt: currentTime.add(_reviewInterval(nextMastery)),
      );
    }
    await _saveRecords(records);
  }

  Future<void> setFavorite({
    required String word,
    required bool isFavorite,
    String? categoryId,
    DateTime? now,
  }) async {
    final normalized = _normalizeWord(word);
    if (normalized.isEmpty) {
      return;
    }
    final activeCategoryId = _activeCategoryIdFor(
      normalized,
      preferredCategoryId: categoryId,
    );
    if (activeCategoryId == null) {
      return;
    }
    final records = await getRecords();
    final index = records.indexWhere((record) => record.word == normalized);
    if (index < 0) {
      if (categoryId == null) {
        return;
      }
      final currentTime = now ?? DateTime.now();
      records.add(
        LearnedWordRecord(
          word: normalized,
          categoryId: activeCategoryId,
          timesFound: 0,
          firstSeenAt: currentTime,
          lastSeenAt: currentTime,
          isFavorite: isFavorite,
          masteryLevel: 0,
          nextReviewAt: currentTime,
        ),
      );
    } else {
      records[index] = records[index].copyWith(isFavorite: isFavorite);
    }
    await _saveRecords(records);
  }

  Future<bool> toggleFavorite(String word) async {
    final record = await getRecord(word);
    if (record == null) {
      return false;
    }
    final nextValue = !record.isFavorite;
    await setFavorite(word: record.word, isFavorite: nextValue);
    return nextValue;
  }

  Future<int> learnedCount() async {
    return (await getRecords()).length;
  }

  Future<int> favoriteCount() async {
    final records = await getRecords();
    return records.where((record) => record.isFavorite).length;
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  Future<void> _saveRecords(List<LearnedWordRecord> records) async {
    records.sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    final prefs = await _getPreferences();
    await _writeRecords(prefs, records);
  }

  static Future<void> _writeRecords(
    SharedPreferences prefs,
    List<LearnedWordRecord> records,
  ) async {
    await prefs.setString(
      recordsKey,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }

  static List<LearnedWordRecord> _decodeRecords(String? raw) {
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(LearnedWordRecord.fromJson)
          .whereType<LearnedWordRecord>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}

String _normalizeWord(String word) => word.trim().toUpperCase();

String? _activeCategoryIdFor(String word, {String? preferredCategoryId}) {
  final normalized = _normalizeWord(word);
  if (preferredCategoryId != null) {
    final normalizedCategoryId = preferredCategoryId.trim().toLowerCase();
    for (final category in wordCategories) {
      if (category.id == normalizedCategoryId &&
          category.words.contains(normalized)) {
        return category.id;
      }
    }
  }
  for (final category in wordCategories) {
    if (category.words.contains(normalized)) {
      return category.id;
    }
  }
  return null;
}

Duration _reviewInterval(int masteryLevel) {
  return Duration(
    days: switch (masteryLevel.clamp(0, 5)) {
      0 => 1,
      1 => 1,
      2 => 2,
      3 => 4,
      4 => 7,
      _ => 14,
    },
  );
}
