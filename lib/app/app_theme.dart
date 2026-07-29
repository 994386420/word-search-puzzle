import 'package:flutter/material.dart';

import '../features/word_search/data/appearance_preference_store.dart';

abstract final class ClayWorldColors {
  static const mintSky = Color(0xFFD9F6E4);
  static const mintSkyTop = Color(0xFFEAFBEF);
  static const cream = Color(0xFFFFF4D2);
  static const creamHighlight = Color(0xFFFFFBEF);
  static const creamEdge = Color(0xFFE5CFA2);
  static const deepPurple = Color(0xFF54236F);
  static const deepPurpleShadow = Color(0xFF351545);
  static const teal = Color(0xFF19B7AA);
  static const tealShadow = Color(0xFF0C7E78);
  static const coral = Color(0xFFFF6658);
  static const coralShadow = Color(0xFFC83E35);
  static const yellow = Color(0xFFFFC928);
  static const yellowShadow = Color(0xFFD9980B);
  static const grass = Color(0xFF76C93E);
  static const grassDark = Color(0xFF379649);
  static const softInk = Color(0xFF3A2750);
}

@immutable
class WordSearchPalette {
  const WordSearchPalette({
    required this.isDark,
    required this.pageGradientColors,
    required this.pageGradientStops,
    required this.pageForegroundColor,
    required this.pageMutedForegroundColor,
    required this.titleColor,
    required this.bodyColor,
    required this.mutedColor,
    required this.sheetSurface,
    required this.tileSurface,
    required this.tileBorder,
    required this.iconSurface,
    required this.headerButtonBackground,
    required this.headerButtonForeground,
    required this.headerButtonBorder,
    required this.backdropGlowAlpha,
    required this.backdropRayAlpha,
    required this.groundColor,
    required this.frontGroundColor,
    this.levelButtonColor = const Color(0xFF45DF76),
    this.levelButtonShadow = const Color(0xFF16A34A),
    this.classicButtonColor = const Color(0xFF11CFE8),
    this.classicButtonShadow = const Color(0xFF0891B2),
    this.speedButtonColor = const Color(0xFF7C6CF4),
    this.speedButtonShadow = const Color(0xFF5145CD),
    this.refreshAccent = const Color(0xFFFFB84D),
    this.boardSurface = const Color(0xFFFFFAEA),
    this.boardLetterColor = const Color(0xFF111827),
    this.boardMutedLetterColor = const Color(0xFF899993),
    this.hintColor = const Color(0xFFFACC15),
    this.wordListSurface = const Color(0xFFFFFBEF),
    this.celebrationSurfaceStart = const Color(0xFFFFFFFF),
    this.celebrationSurfaceEnd = const Color(0xFFFFF3C7),
  });

  final bool isDark;
  final List<Color> pageGradientColors;
  final List<double> pageGradientStops;
  final Color pageForegroundColor;
  final Color pageMutedForegroundColor;
  final Color titleColor;
  final Color bodyColor;
  final Color mutedColor;
  final Color sheetSurface;
  final Color tileSurface;
  final Color tileBorder;
  final Color iconSurface;
  final Color headerButtonBackground;
  final Color headerButtonForeground;
  final Color headerButtonBorder;
  final double backdropGlowAlpha;
  final double backdropRayAlpha;
  final Color groundColor;
  final Color frontGroundColor;
  final Color levelButtonColor;
  final Color levelButtonShadow;
  final Color classicButtonColor;
  final Color classicButtonShadow;
  final Color speedButtonColor;
  final Color speedButtonShadow;
  final Color refreshAccent;
  final Color boardSurface;
  final Color boardLetterColor;
  final Color boardMutedLetterColor;
  final Color hintColor;
  final Color wordListSurface;
  final Color celebrationSurfaceStart;
  final Color celebrationSurfaceEnd;

  LinearGradient get pageGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: pageGradientColors,
    stops: pageGradientStops,
  );

  static const light = freshLight;
  static const dark = freshDark;

  static const freshLight = WordSearchPalette(
    isDark: false,
    pageGradientColors: [
      ClayWorldColors.mintSkyTop,
      ClayWorldColors.mintSky,
      Color(0xFFBDEB9B),
    ],
    pageGradientStops: [0, 0.58, 1],
    pageForegroundColor: ClayWorldColors.deepPurple,
    pageMutedForegroundColor: Color(0xFF675A70),
    titleColor: ClayWorldColors.deepPurple,
    bodyColor: ClayWorldColors.softInk,
    mutedColor: Color(0xFF74697B),
    sheetSurface: ClayWorldColors.cream,
    tileSurface: ClayWorldColors.creamHighlight,
    tileBorder: ClayWorldColors.creamEdge,
    iconSurface: Color(0xFFF5E5BE),
    headerButtonBackground: ClayWorldColors.creamHighlight,
    headerButtonForeground: ClayWorldColors.deepPurple,
    headerButtonBorder: ClayWorldColors.creamEdge,
    backdropGlowAlpha: 0.17,
    backdropRayAlpha: 0.075,
    groundColor: Color(0x2477BFA1),
    frontGroundColor: Color(0x1F4F9B72),
    levelButtonColor: ClayWorldColors.coral,
    levelButtonShadow: ClayWorldColors.coralShadow,
    classicButtonColor: ClayWorldColors.teal,
    classicButtonShadow: ClayWorldColors.tealShadow,
    speedButtonColor: Color(0xFF4D8FD8),
    speedButtonShadow: Color(0xFF2C6FB5),
    refreshAccent: ClayWorldColors.yellow,
    boardSurface: ClayWorldColors.cream,
    boardLetterColor: ClayWorldColors.deepPurpleShadow,
    boardMutedLetterColor: Color(0xFF879B96),
    hintColor: ClayWorldColors.yellow,
    wordListSurface: ClayWorldColors.cream,
    celebrationSurfaceStart: Color(0xFFFFFFFF),
    celebrationSurfaceEnd: Color(0xFFFFE7BD),
  );

  static const freshDark = WordSearchPalette(
    isDark: true,
    pageGradientColors: [
      Color(0xFF16343A),
      Color(0xFF243D42),
      Color(0xFF29453B),
    ],
    pageGradientStops: [0, 0.58, 1],
    pageForegroundColor: Color(0xFFF1FCFA),
    pageMutedForegroundColor: Color(0xFFAFC7C2),
    titleColor: Color(0xFFF1FCFA),
    bodyColor: Color(0xFFD6F1EC),
    mutedColor: Color(0xFFAFC7C2),
    sheetSurface: Color(0xF51B3438),
    tileSurface: Color(0xFF24413F),
    tileBorder: Color(0xFF43645E),
    iconSurface: Color(0xFF2B5550),
    headerButtonBackground: Color(0xDDF5FFFC),
    headerButtonForeground: Color(0xFF164B51),
    headerButtonBorder: Color(0x6659C9BC),
    backdropGlowAlpha: 0.13,
    backdropRayAlpha: 0.07,
    groundColor: Color(0x2650BE90),
    frontGroundColor: Color(0x2250A970),
    levelButtonColor: Color(0xFFFF8254),
    levelButtonShadow: Color(0xFFB94B2A),
    classicButtonColor: Color(0xFF35BDB5),
    classicButtonShadow: Color(0xFF147A76),
    speedButtonColor: Color(0xFF5B95D8),
    speedButtonShadow: Color(0xFF315F9A),
    refreshAccent: Color(0xFFFFB84D),
    boardSurface: Color(0xFF1B3034),
    boardLetterColor: Color(0xFFF2FCFA),
    boardMutedLetterColor: Color(0xFF9BB2AD),
    hintColor: Color(0xFFFFCD57),
    wordListSurface: Color(0xF421383A),
    celebrationSurfaceStart: Color(0xFF294447),
    celebrationSurfaceEnd: Color(0xFF3E3529),
  );

  static const starryLight = WordSearchPalette(
    isDark: false,
    pageGradientColors: [
      Color(0xFFBFDFFF),
      Color(0xFFD8D7FF),
      Color(0xFFC7F4E9),
    ],
    pageGradientStops: [0, 0.6, 1],
    pageForegroundColor: Color(0xFFFFFFFF),
    pageMutedForegroundColor: Color(0xFFDCE7FF),
    titleColor: Color(0xFF22547A),
    bodyColor: Color(0xFF24455F),
    mutedColor: Color(0xFF5B7186),
    sheetSurface: Color(0xF7F8FBFF),
    tileSurface: Color(0xFFEFF7FF),
    tileBorder: Color(0xFFD4E3FF),
    iconSurface: Color(0xFFE4F0FF),
    headerButtonBackground: Color(0xDCF8FBFF),
    headerButtonForeground: Color(0xFF284A78),
    headerButtonBorder: Color(0xFFCAE3FF),
    backdropGlowAlpha: 0.18,
    backdropRayAlpha: 0.095,
    groundColor: Color(0x2496D9D0),
    frontGroundColor: Color(0x1F9389E8),
    levelButtonColor: Color(0xFF38D9B9),
    levelButtonShadow: Color(0xFF0F9A9A),
    classicButtonColor: Color(0xFF38BDF8),
    classicButtonShadow: Color(0xFF2563EB),
    speedButtonColor: Color(0xFF8B7CFF),
    speedButtonShadow: Color(0xFF5B4BE0),
    refreshAccent: Color(0xFFA78BFA),
    boardSurface: Color(0xFFF4F7FF),
    boardLetterColor: Color(0xFF10233F),
    boardMutedLetterColor: Color(0xFF74829E),
    hintColor: Color(0xFFFFD166),
    wordListSurface: Color(0xFFF7FAFF),
    celebrationSurfaceStart: Color(0xFFFFFFFF),
    celebrationSurfaceEnd: Color(0xFFEAF1FF),
  );

  static const starryDark = WordSearchPalette(
    isDark: true,
    pageGradientColors: [
      Color(0xFF09172F),
      Color(0xFF20275A),
      Color(0xFF0D3C4D),
    ],
    pageGradientStops: [0, 0.56, 1],
    pageForegroundColor: Color(0xFFF5F8FF),
    pageMutedForegroundColor: Color(0xFFC7D6F7),
    titleColor: Color(0xFFEAF4FF),
    bodyColor: Color(0xFFD7EAFF),
    mutedColor: Color(0xFFA7BCE3),
    sheetSurface: Color(0xF516233E),
    tileSurface: Color(0xFF1D2A49),
    tileBorder: Color(0xFF43567D),
    iconSurface: Color(0xFF26385E),
    headerButtonBackground: Color(0xDDEAF8FF),
    headerButtonForeground: Color(0xFF263D78),
    headerButtonBorder: Color(0x666CC7FF),
    backdropGlowAlpha: 0.15,
    backdropRayAlpha: 0.08,
    groundColor: Color(0x2422D3EE),
    frontGroundColor: Color(0x238B5CF6),
    levelButtonColor: Color(0xFF22D3EE),
    levelButtonShadow: Color(0xFF0E7490),
    classicButtonColor: Color(0xFF38BDF8),
    classicButtonShadow: Color(0xFF1D4ED8),
    speedButtonColor: Color(0xFF8B7CFF),
    speedButtonShadow: Color(0xFF4F46E5),
    refreshAccent: Color(0xFFA78BFA),
    boardSurface: Color(0xFF17243E),
    boardLetterColor: Color(0xFFEAF4FF),
    boardMutedLetterColor: Color(0xFF90A8CF),
    hintColor: Color(0xFFFFD166),
    wordListSurface: Color(0xF41A2744),
    celebrationSurfaceStart: Color(0xFF1E2B4A),
    celebrationSurfaceEnd: Color(0xFF101C35),
  );

  static const candyLight = WordSearchPalette(
    isDark: false,
    pageGradientColors: [
      Color(0xFFFFD8DE),
      Color(0xFFFFF0B6),
      Color(0xFFC9F5E5),
    ],
    pageGradientStops: [0, 0.58, 1],
    pageForegroundColor: Color(0xFF9D2862),
    pageMutedForegroundColor: Color(0xFF7B6676),
    titleColor: Color(0xFF9D2862),
    bodyColor: Color(0xFF7A355C),
    mutedColor: Color(0xFF7B6676),
    sheetSurface: Color(0xF7FFF8FB),
    tileSurface: Color(0xFFFFF2F6),
    tileBorder: Color(0xFFFFD1E2),
    iconSurface: Color(0xFFFFE6F0),
    headerButtonBackground: Color(0xE6FFFFFF),
    headerButtonForeground: Color(0xFF8E285B),
    headerButtonBorder: Color(0xFFFFCADC),
    backdropGlowAlpha: 0.2,
    backdropRayAlpha: 0.1,
    groundColor: Color(0x22F472B6),
    frontGroundColor: Color(0x2099F6E4),
    levelButtonColor: Color(0xFFFF7AB3),
    levelButtonShadow: Color(0xFFD94686),
    classicButtonColor: Color(0xFF45DCE7),
    classicButtonShadow: Color(0xFF0EA5B7),
    speedButtonColor: Color(0xFFFF8AB8),
    speedButtonShadow: Color(0xFFDB5A8E),
    refreshAccent: Color(0xFFFFB86B),
    boardSurface: Color(0xFFFFF6FA),
    boardLetterColor: Color(0xFF4C1D3F),
    boardMutedLetterColor: Color(0xFF9E6C83),
    hintColor: Color(0xFFFFC857),
    wordListSurface: Color(0xFFFFF7FB),
    celebrationSurfaceStart: Color(0xFFFFFFFF),
    celebrationSurfaceEnd: Color(0xFFFFE4F0),
  );

  static const candyDark = WordSearchPalette(
    isDark: true,
    pageGradientColors: [
      Color(0xFF35172F),
      Color(0xFF51304B),
      Color(0xFF263B50),
    ],
    pageGradientStops: [0, 0.58, 1],
    pageForegroundColor: Color(0xFFFFEFF7),
    pageMutedForegroundColor: Color(0xFFD9B4C8),
    titleColor: Color(0xFFFFEFF7),
    bodyColor: Color(0xFFFFD7EC),
    mutedColor: Color(0xFFD9B4C8),
    sheetSurface: Color(0xF52B1A2C),
    tileSurface: Color(0xFF3A2539),
    tileBorder: Color(0xFF65405B),
    iconSurface: Color(0xFF4C2D48),
    headerButtonBackground: Color(0xEFFFF7FB),
    headerButtonForeground: Color(0xFF78214C),
    headerButtonBorder: Color(0x77FF8AB8),
    backdropGlowAlpha: 0.14,
    backdropRayAlpha: 0.075,
    groundColor: Color(0x26FF7AB3),
    frontGroundColor: Color(0x2267E8F9),
    levelButtonColor: Color(0xFFFF7AB3),
    levelButtonShadow: Color(0xFFBE3D74),
    classicButtonColor: Color(0xFF67E8F9),
    classicButtonShadow: Color(0xFF0891B2),
    speedButtonColor: Color(0xFFFF8AB8),
    speedButtonShadow: Color(0xFFBE3D74),
    refreshAccent: Color(0xFFFFB86B),
    boardSurface: Color(0xFF3A2539),
    boardLetterColor: Color(0xFFFFEFF7),
    boardMutedLetterColor: Color(0xFFD9B4C8),
    hintColor: Color(0xFFFFCA66),
    wordListSurface: Color(0xF43A2539),
    celebrationSurfaceStart: Color(0xFF47273E),
    celebrationSurfaceEnd: Color(0xFF261A30),
  );

  static WordSearchPalette resolve({
    required Brightness brightness,
    required AppSkin skin,
  }) {
    final dark = brightness == Brightness.dark;
    return switch (skin) {
      AppSkin.fresh => dark ? freshDark : freshLight,
      AppSkin.starry => dark ? starryDark : starryLight,
      AppSkin.candy => dark ? candyDark : candyLight,
    };
  }

  static WordSearchPalette of(BuildContext context) {
    final visualTheme = Theme.of(context).extension<WordSearchVisualTheme>();
    if (visualTheme != null) {
      return visualTheme.palette;
    }
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

@immutable
class WordSearchVisualTheme extends ThemeExtension<WordSearchVisualTheme> {
  const WordSearchVisualTheme({required this.palette, required this.skin});

  final WordSearchPalette palette;
  final AppSkin skin;

  @override
  WordSearchVisualTheme copyWith({WordSearchPalette? palette, AppSkin? skin}) {
    return WordSearchVisualTheme(
      palette: palette ?? this.palette,
      skin: skin ?? this.skin,
    );
  }

  @override
  WordSearchVisualTheme lerp(
    covariant ThemeExtension<WordSearchVisualTheme>? other,
    double t,
  ) {
    if (other is! WordSearchVisualTheme) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

class WordSearchAppTheme {
  const WordSearchAppTheme._();

  static ThemeData light(AppSkin skin) {
    final palette = WordSearchPalette.resolve(
      brightness: Brightness.light,
      skin: skin,
    );
    return _theme(
      brightness: Brightness.light,
      seedColor: palette.classicButtonColor,
      scaffoldBackgroundColor: palette.pageGradientColors.last,
      palette: palette,
      skin: skin,
    );
  }

  static ThemeData dark(AppSkin skin) {
    final palette = WordSearchPalette.resolve(
      brightness: Brightness.dark,
      skin: skin,
    );
    return _theme(
      brightness: Brightness.dark,
      seedColor: palette.classicButtonColor,
      scaffoldBackgroundColor: palette.pageGradientColors.first,
      palette: palette,
      skin: skin,
    );
  }

  static ThemeData _theme({
    required Brightness brightness,
    required Color seedColor,
    required Color scaffoldBackgroundColor,
    required WordSearchPalette palette,
    required AppSkin skin,
  }) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: palette.tileBorder, width: 2),
    );
    final buttonTextStyle = TextStyle(
      color: palette.bodyColor,
      fontSize: 14,
      fontWeight: FontWeight.w900,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
      extensions: [WordSearchVisualTheme(palette: palette, skin: skin)],
      fontFamily: 'Arial',
      fontFamilyFallback: const [
        'PingFang SC',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
        'Apple SD Gothic Neo',
        'Noto Sans KR',
        'sans-serif',
      ],
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
      ),
      cardTheme: CardThemeData(
        color: palette.tileSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.tileBorder, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          shape: buttonShape,
          elevation: 7,
          shadowColor: palette.titleColor.withValues(alpha: 0.34),
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: palette.tileSurface.withValues(alpha: 0.86),
          foregroundColor: palette.bodyColor,
          side: BorderSide(color: palette.tileBorder, width: 1.3),
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.bodyColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: buttonTextStyle,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.sheetSurface,
        contentTextStyle: TextStyle(
          color: palette.bodyColor,
          fontWeight: FontWeight.w800,
        ),
        elevation: 10,
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.tileBorder),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.tileBorder.withValues(alpha: 0.82),
        space: 1,
        thickness: 1,
      ),
    );
  }
}
