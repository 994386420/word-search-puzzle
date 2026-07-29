import 'package:flutter/material.dart';

import '../features/word_search/data/appearance_preference_store.dart';
import 'app_theme.dart';

class SkinVisuals {
  const SkinVisuals._();

  static AppSkin of(BuildContext context) {
    return Theme.of(context).extension<WordSearchVisualTheme>()?.skin ??
        AppSkin.fresh;
  }

  static String homeBackgroundAsset(AppSkin skin) {
    return switch (skin) {
      AppSkin.fresh => 'assets/brand/home_background.webp',
      AppSkin.starry => 'assets/brand/home_background_starry.webp',
      AppSkin.candy => 'assets/brand/home_background_candy.webp',
    };
  }

  static String sceneAsset(String freshAsset, AppSkin skin) {
    if (skin == AppSkin.fresh) {
      return freshAsset;
    }
    const versionMarker = '-v1.';
    final markerIndex = freshAsset.lastIndexOf(versionMarker);
    if (markerIndex == -1) {
      return freshAsset;
    }
    return '${freshAsset.substring(0, markerIndex)}-${skin.name}-v1.webp';
  }
}
