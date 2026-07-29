import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:word_search_puzzle/app/skin_visuals.dart';
import 'package:word_search_puzzle/features/word_search/data/appearance_preference_store.dart';
import 'package:word_search_puzzle/features/word_search/domain/categories.dart';
import 'package:word_search_puzzle/features/word_search/presentation/widgets/theme_scene_assets.dart';

void main() {
  test('every word theme resolves to a distinct clay scene', () {
    final paths = wordCategories.map(clayThemeSceneAsset).toList();

    expect(paths, hasLength(wordCategories.length));
    expect(paths.toSet(), hasLength(wordCategories.length));
    expect(paths, everyElement(startsWith('assets/ui/clay/scenes/theme-')));
  });

  test('every mapped clay scene exists in the asset bundle source', () {
    final freshPaths = <String>{
      ...wordCategories.map(clayThemeSceneAsset),
      clayStatsSceneAsset,
      clayReviewSceneAsset,
      'assets/ui/clay/scenes/daily-world-v1.webp',
      'assets/ui/clay/scenes/game-garden-v1.webp',
      'assets/ui/clay/scenes/leaderboard-world-v1.webp',
      'assets/ui/clay/scenes/picture-garden-v1.webp',
    };

    for (final freshPath in freshPaths) {
      final skinPaths = AppSkin.values
          .map((skin) => SkinVisuals.sceneAsset(freshPath, skin))
          .toSet();
      expect(skinPaths, hasLength(AppSkin.values.length));
      for (final path in skinPaths) {
        expect(File(path).existsSync(), isTrue, reason: 'Missing scene: $path');
      }
    }
  });
}
