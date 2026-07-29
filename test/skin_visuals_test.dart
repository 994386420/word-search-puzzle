import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_search_puzzle/app/app_theme.dart';
import 'package:word_search_puzzle/app/skin_visuals.dart';
import 'package:word_search_puzzle/features/word_search/data/appearance_preference_store.dart';
import 'package:word_search_puzzle/features/word_search/presentation/widgets/clay_ui.dart';
import 'package:word_search_puzzle/features/word_search/presentation/widgets/playful_page_background.dart';

void main() {
  test('maps every skin to its own home scene asset', () {
    expect(
      SkinVisuals.homeBackgroundAsset(AppSkin.fresh),
      'assets/brand/home_background.webp',
    );
    expect(
      SkinVisuals.homeBackgroundAsset(AppSkin.starry),
      'assets/brand/home_background_starry.webp',
    );
    expect(
      SkinVisuals.homeBackgroundAsset(AppSkin.candy),
      'assets/brand/home_background_candy.webp',
    );
  });

  test('maps every skin to a distinct clay scene file', () {
    const fresh = 'assets/ui/clay/scenes/game-garden-v1.webp';
    expect(SkinVisuals.sceneAsset(fresh, AppSkin.fresh), fresh);
    expect(
      SkinVisuals.sceneAsset(fresh, AppSkin.starry),
      'assets/ui/clay/scenes/game-garden-starry-v1.webp',
    );
    expect(
      SkinVisuals.sceneAsset(fresh, AppSkin.candy),
      'assets/ui/clay/scenes/game-garden-candy-v1.webp',
    );
  });

  test('theme extension retains the active skin', () {
    final theme = WordSearchAppTheme.light(AppSkin.starry);
    final visualTheme = theme.extension<WordSearchVisualTheme>();

    expect(visualTheme, isNotNull);
    expect(visualTheme!.skin, AppSkin.starry);
  });

  test('material color scheme follows the active skin', () {
    final fresh = WordSearchAppTheme.light(AppSkin.fresh);
    final starry = WordSearchAppTheme.light(AppSkin.starry);
    final candy = WordSearchAppTheme.light(AppSkin.candy);

    expect(fresh.colorScheme.primary, isNot(starry.colorScheme.primary));
    expect(starry.colorScheme.primary, isNot(candy.colorScheme.primary));
    expect(candy.colorScheme.primary, isNot(fresh.colorScheme.primary));
  });

  test('header controls remain readable over bright and dark artwork', () {
    const palettes = [
      WordSearchPalette.freshLight,
      WordSearchPalette.freshDark,
      WordSearchPalette.starryLight,
      WordSearchPalette.starryDark,
      WordSearchPalette.candyLight,
      WordSearchPalette.candyDark,
    ];

    for (final palette in palettes) {
      for (final artwork in [Colors.white, Colors.black]) {
        final background = Color.alphaBlend(
          palette.headerButtonBackground,
          artwork,
        );
        expect(
          _contrastRatio(palette.headerButtonForeground, background),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });

  testWidgets('shared pages render the selected skin artwork at full opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WordSearchAppTheme.light(AppSkin.starry),
        home: const PlayfulPageBackground(child: SizedBox.expand()),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/brand/home_background_starry.webp',
    );
    expect(find.byType(Opacity), findsNothing);
    expect(WordSearchPalette.starryLight.pageForegroundColor, Colors.white);
  });

  testWidgets('clay scene artwork follows the selected skin', (tester) async {
    Future<void> pumpScene(AppSkin skin) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WordSearchAppTheme.light(skin),
          home: const ClaySceneBackdrop(
            assetPath: 'assets/ui/clay/scenes/game-garden-v1.webp',
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpScene(AppSkin.fresh);
    expect(
      _sceneAsset(tester, AppSkin.fresh),
      'assets/ui/clay/scenes/game-garden-v1.webp',
    );

    await pumpScene(AppSkin.starry);
    expect(
      _sceneAsset(tester, AppSkin.starry),
      'assets/ui/clay/scenes/game-garden-starry-v1.webp',
    );

    await pumpScene(AppSkin.candy);
    expect(
      _sceneAsset(tester, AppSkin.candy),
      'assets/ui/clay/scenes/game-garden-candy-v1.webp',
    );
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('starry clay titles remain readable over night scenes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WordSearchAppTheme.light(AppSkin.starry),
        home: const ClayWorldTitle('Night map'),
      ),
    );

    final title = tester
        .widgetList<Text>(find.text('NIGHT MAP'))
        .singleWhere((layer) => layer.style?.color != null);
    expect(
      title.style?.color,
      WordSearchPalette.starryLight.pageForegroundColor,
    );
  });
}

String _sceneAsset(WidgetTester tester, AppSkin skin) {
  final image = tester.widget<Image>(
    find.byKey(ValueKey('clay-scene-asset-${skin.name}')),
  );
  return (image.image as AssetImage).assetName;
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() >= background.computeLuminance()
      ? foreground
      : background;
  final darker = lighter == foreground ? background : foreground;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
