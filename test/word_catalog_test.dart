import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/domain/kid_word_catalog.dart';
import 'package:word_search_puzzle/features/word_search/domain/models.dart';
import 'package:word_search_puzzle/features/word_search/domain/word_learning.dart';

void main() {
  test('word categories follow the child learning path', () {
    expect(wordCategories.map((category) => category.id), [
      'animals',
      'food',
      'nature',
      'sports',
      'space',
      'tech',
    ]);
  });

  test('every catalog word has an audio asset and learning copy', () {
    for (final category in wordCategories) {
      for (final word in category.words) {
        final audio = File('assets/audio/words/${word.toLowerCase()}.mp3');
        final learning = wordLearningEntryFor(word);
        final metadata = kidWordMetadataFor(word);

        expect(audio.existsSync(), isTrue, reason: '$word needs word audio');
        expect(
          learning.en,
          isNot('A useful English word'),
          reason: '$word needs an English learning hint',
        );
        expect(learning.zh, isNotEmpty, reason: '$word needs Chinese copy');
        expect(learning.ko, isNotEmpty, reason: '$word needs Korean copy');
        expect(metadata.word, word, reason: '$word needs kid metadata');
      }
    }
  });

  test('each difficulty has enough age-appropriate words', () {
    for (final category in wordCategories) {
      for (final difficulty in Difficulty.values) {
        final words = kidWordsForDifficulty(category.words, difficulty);
        expect(
          words.length,
          greaterThanOrEqualTo(difficulty.wordCount),
          reason: '${category.id} needs enough ${difficulty.name} words',
        );
      }
    }
  });

  test('every mapped picture clue has a bundled image asset', () {
    for (final entry in {
      ...kidWordVisualAssets,
      ...kidWordCategoryVisualAssets,
    }.entries) {
      expect(
        File(entry.value).existsSync(),
        isTrue,
        reason: '${entry.key} needs the mapped picture clue asset',
      );
    }
  });

  test('every theme provides picture clues for all twenty-five words', () {
    for (final category in wordCategories) {
      final illustrated = category.words
          .where(
            (word) =>
                kidWordVisualAssetFor(word, categoryId: category.id) != null,
          )
          .toList(growable: false);
      expect(
        illustrated,
        hasLength(25),
        reason: '${category.id} needs twenty-five illustrated picture clues',
      );
    }
  });

  test('six themes bundle exactly 150 distinct word illustrations', () {
    final mappedAssets = <String>[];
    for (final category in wordCategories) {
      expect(
        category.words.length,
        25,
        reason: '${category.id} needs exactly 25 learning words',
      );
      for (final word in category.words) {
        final asset = kidWordVisualAssetFor(word, categoryId: category.id);
        if (asset != null) {
          mappedAssets.add(asset);
        }
      }
    }

    final bundledAssets = Directory('assets/words')
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path)
        .where(
          (path) =>
              path.endsWith('.webp') && !path.endsWith('contact-sheet.webp'),
        )
        .toSet();

    expect(mappedAssets, hasLength(150));
    expect(mappedAssets.toSet(), hasLength(150));
    expect(mappedAssets.toSet(), bundledAssets);
    expect(
      kidWordVisualAssetFor('CLOUD', categoryId: 'nature'),
      isNot(kidWordVisualAssetFor('CLOUD', categoryId: 'tech')),
    );
  });

  test('all 150 illustrations decode at the expected resolution', () async {
    for (final category in wordCategories) {
      for (final word in category.words) {
        final assetPath = kidWordVisualAssetFor(word, categoryId: category.id);
        if (assetPath == null) {
          continue;
        }
        final bytes = await File(assetPath).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(
          frame.image.width,
          512,
          reason: '$category/$word illustration width is inconsistent',
        );
        expect(
          frame.image.height,
          512,
          reason: '$category/$word illustration height is inconsistent',
        );
        frame.image.dispose();
        codec.dispose();
      }
    }
  });

  test('smart word selection varies free-play rounds', () {
    final category = wordCategories.first;
    const config = PuzzleConfig(
      gridSize: 10,
      wordCount: 9,
      directionMode: PuzzleDirectionMode.reverse,
    );
    final rounds = <String>{};
    for (var seed = 0; seed < 12; seed++) {
      final words = selectKidWordsForRound(
        category.words,
        Difficulty.medium,
        config: config,
        random: Random(seed),
        categoryId: category.id,
      )..sort();
      rounds.add(words.join(','));
    }

    expect(rounds.length, greaterThanOrEqualTo(8));
  });

  test('picture selection never chooses a word without artwork', () {
    for (final category in wordCategories) {
      final selected = selectKidWordsForRound(
        category.words,
        Difficulty.hard,
        config: Difficulty.hard.puzzleConfig,
        random: Random(31),
        clueMode: ClueMode.pictures,
        categoryId: category.id,
      );

      expect(selected, hasLength(Difficulty.hard.wordCount));
      expect(
        selected.every(
          (word) =>
              kidWordVisualAssetFor(word, categoryId: category.id) != null,
        ),
        isTrue,
      );
    }
  });
}
