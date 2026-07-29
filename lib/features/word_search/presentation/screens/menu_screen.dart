import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../app/appearance_controller.dart';
import '../../../../app/app_theme.dart';
import '../../../../app/language_controller.dart';
import '../../../../app/skin_visuals.dart';
import '../../../../l10n/app_strings.dart';
import '../../data/ad_config.dart';
import '../../data/ad_service.dart';
import '../../data/appearance_preference_store.dart';
import '../../data/coin_store.dart';
import '../../data/daily_challenge_store.dart';
import '../../data/feedback_service.dart';
import '../../data/language_preference_store.dart';
import '../../data/level_progress_store.dart';
import '../../data/progress_store.dart';
import '../../data/voice_guide_service.dart';
import '../../domain/categories.dart';
import '../../domain/level_progression.dart';
import '../../domain/models.dart';
import '../widgets/category_card.dart';
import '../widgets/category_thumbnail.dart';
import '../widgets/clay_ui.dart';
import '../widgets/game_refresh_indicator.dart';
import '../widgets/playful_page_background.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    required this.onContinueLearning,
    required this.onChooseThemes,
    required this.onDailyChallenge,
    required this.onLeaderboard,
    required this.onStats,
    this.onRefreshReady,
    super.key,
  });

  final Future<void> Function() onContinueLearning;
  final Future<void> Function() onChooseThemes;
  final Future<void> Function() onDailyChallenge;
  final VoidCallback onLeaderboard;
  final VoidCallback onStats;
  final ValueChanged<VoidCallback>? onRefreshReady;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  final _coinStore = const CoinStore();
  final _levelProgressStore = const LevelProgressStore();
  final _progressStore = ProgressStore();
  late final AnimationController _entryMotion;
  Timer? _guideTimer;
  LevelDefinition _activeLevel = firstCampaignLevel();
  int _coinBalance = CoinStore.initialBalance;
  bool _showStartGuide = false;

  @override
  void initState() {
    super.initState();
    _entryMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );
    _loadLevel();
    widget.onRefreshReady?.call(_loadLevel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 620), () {
        if (mounted) {
          _entryMotion.forward();
        }
      });
      unawaited(_maybeShowStartGuide());
    });
  }

  @override
  void dispose() {
    _guideTimer?.cancel();
    _entryMotion.dispose();
    super.dispose();
  }

  Future<void> _loadLevel() async {
    final values = await Future.wait<Object>([
      _levelProgressStore.load(),
      _coinStore.getBalance(),
    ]);
    if (!mounted) {
      return;
    }
    final progress = values[0] as LevelProgressSnapshot;
    final activeLevel = progress.activeLevel;
    setState(() {
      _coinBalance = values[1] as int;
      _activeLevel = activeLevel;
    });
  }

  Future<void> _showSettings() async {
    unawaited(FeedbackService.instance.tap());
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MainMenuSettingsSheet(
          onStats: () {
            Navigator.of(context).pop();
            widget.onStats();
          },
          onPrivacy: () async {
            Navigator.of(context).pop();
            await AdService.instance.showPrivacyOptions();
          },
        );
      },
    );
  }

  Future<void> _showCoinWallet() async {
    unawaited(AdService.instance.loadRewarded());
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) => _CoinWalletSheet(
        balance: _coinBalance,
        canWatchVideo: AdService.instance.isSupported,
      ),
    );
    if (!mounted || action != 'video') {
      return;
    }
    final earned = await AdService.instance.showRewardedUnlock();
    if (!mounted) {
      return;
    }
    if (!earned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).rewardedUnavailable)),
      );
      return;
    }
    final reward = await _coinStore.earn(CoinStore.rewardedVideoCoins);
    if (mounted) {
      setState(() => _coinBalance = reward.balance);
    }
  }

  Future<void> _maybeShowStartGuide() async {
    final seen = await _progressStore.hasSeenHomeStartGuide();
    if (!mounted || seen) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 2380));
    if (!mounted) {
      return;
    }
    setState(() => _showStartGuide = true);
    unawaited(
      VoiceGuideService.instance.playCue(
        VoiceGuideCue.homeIntro,
        interrupt: true,
        minInterval: const Duration(seconds: 12),
      ),
    );
    await _progressStore.markHomeStartGuideSeen();
    _guideTimer?.cancel();
    _guideTimer = Timer(const Duration(seconds: 6), _hideStartGuide);
  }

  void _hideStartGuide() {
    _guideTimer?.cancel();
    if (mounted && _showStartGuide) {
      setState(() => _showStartGuide = false);
    }
  }

  void _continueLearning() {
    _hideStartGuide();
    unawaited(widget.onContinueLearning());
  }

  void _chooseThemes() {
    _hideStartGuide();
    unawaited(widget.onChooseThemes());
  }

  void _openDailyChallenge() {
    _hideStartGuide();
    unawaited(
      VoiceGuideService.instance.playCue(
        VoiceGuideCue.dailyReady,
        interrupt: true,
        minInterval: const Duration(seconds: 8),
      ),
    );
    unawaited(widget.onDailyChallenge());
  }

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final skin = SkinVisuals.of(context);
    final useLightStatusIcons = palette.isDark || skin == AppSkin.starry;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: useLightStatusIcons
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: useLightStatusIcons
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: palette.pageGradient),
          child: Stack(
            children: [
              Positioned.fill(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      SkinVisuals.homeBackgroundAsset(skin),
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomCenter,
                      filterQuality: FilterQuality.high,
                      semanticLabel: 'Clay meadow background',
                    ),
                    if (palette.isDark)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              palette.pageGradientColors.first.withValues(
                                alpha: 0.46,
                              ),
                              Colors.transparent,
                              palette.pageGradientColors.last.withValues(
                                alpha: 0.22,
                              ),
                            ],
                            stops: const [0, 0.48, 1],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Column(
                        children: [
                          _MenuEntryReveal(
                            animation: _entryMotion,
                            start: 0,
                            end: 0.55,
                            dy: -12,
                            child: _MainMenuTopBar(
                              onSettings: _showSettings,
                              onDaily: _openDailyChallenge,
                              onLeaderboard: widget.onLeaderboard,
                              coinBalance: _coinBalance,
                              onCoins: _showCoinWallet,
                            ),
                          ),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: 340,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _MenuEntryReveal(
                                      animation: _entryMotion,
                                      start: 0.08,
                                      end: 0.62,
                                      dy: 18,
                                      child: const _ReferenceWordSearchLogo(),
                                    ),
                                    const SizedBox(height: 12),
                                    _MenuEntryReveal(
                                      animation: _entryMotion,
                                      start: 0.18,
                                      end: 0.78,
                                      dy: 24,
                                      scaleFrom: 0.96,
                                      child: _ReferenceHomeStage(
                                        activeLevel: _activeLevel,
                                        onContinue: _continueLearning,
                                        onClassic: _chooseThemes,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _StartModeGuideOverlay(
                                      visible: _showStartGuide,
                                      palette: palette,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 26 + MediaQuery.paddingOf(context).bottom,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuEntryReveal extends StatelessWidget {
  const _MenuEntryReveal({
    required this.animation,
    required this.child,
    required this.start,
    required this.end,
    this.dy = 18,
    this.scaleFrom = 0.98,
  });

  final Animation<double> animation;
  final Widget child;
  final double start;
  final double end;
  final double dy;
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final raw = ((animation.value - start) / (end - start)).clamp(0.0, 1.0);
        final value = Curves.easeOutCubic.transform(raw);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, dy * (1 - value)),
            child: Transform.scale(
              scale: scaleFrom + (1 - scaleFrom) * value,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _StartModeGuideOverlay extends StatefulWidget {
  const _StartModeGuideOverlay({required this.visible, required this.palette});

  final bool visible;
  final WordSearchPalette palette;

  @override
  State<_StartModeGuideOverlay> createState() => _StartModeGuideOverlayState();
}

class _StartModeGuideOverlayState extends State<_StartModeGuideOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    if (widget.visible) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _StartModeGuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.visible && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          height: widget.visible ? 66 : 0,
          child: AnimatedOpacity(
            opacity: widget.visible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final pulse = Curves.easeInOut.transform(_pulse.value);
                return Transform.translate(
                  offset: Offset(0, -3 * pulse),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _StartModeGuidePainter(
                            palette: widget.palette,
                            pulse: pulse,
                          ),
                        ),
                      ),
                      _StartModeGuideBubble(palette: widget.palette),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StartModeGuideBubble extends StatelessWidget {
  const _StartModeGuideBubble({required this.palette});

  final WordSearchPalette palette;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: palette.sheetSurface.withValues(
          alpha: palette.isDark ? 0.88 : 0.78,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: palette.isDark ? 0.16 : 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.titleColor.withValues(
              alpha: palette.isDark ? 0.16 : 0.09,
            ),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.touch_app_rounded,
                color: palette.refreshAccent,
                size: 17,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  strings.startGuideTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: palette.classicButtonColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  strings.startGuideBody,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: palette.speedButtonColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartModeGuidePainter extends CustomPainter {
  const _StartModeGuidePainter({required this.palette, required this.pulse});

  final WordSearchPalette palette;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = palette.hintColor.withValues(alpha: 0.12 + pulse * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: 326 + pulse * 18,
          height: 70 + pulse * 10,
        ),
        const Radius.circular(99),
      ),
      glow,
    );

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.52 + pulse * 0.18);
    for (final dx in [-78.0, 78.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(dx, 0),
            width: 134 + pulse * 8,
            height: 62 + pulse * 7,
          ),
          const Radius.circular(99),
        ),
        outlinePaint,
      );
    }

    final sparkPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.38 + pulse * 0.28);
    for (final point in [
      Offset(center.dx - 162, center.dy - 32),
      Offset(center.dx + 162, center.dy - 28),
      Offset(center.dx, center.dy + 38),
    ]) {
      final length = 4 + pulse * 3;
      canvas.drawLine(
        point.translate(-length, 0),
        point.translate(length, 0),
        sparkPaint,
      );
      canvas.drawLine(
        point.translate(0, -length),
        point.translate(0, length),
        sparkPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StartModeGuidePainter oldDelegate) {
    return oldDelegate.palette != palette || oldDelegate.pulse != pulse;
  }
}

class _MainMenuTopBar extends StatelessWidget {
  const _MainMenuTopBar({
    required this.onSettings,
    required this.onDaily,
    required this.onLeaderboard,
    required this.coinBalance,
    required this.onCoins,
  });

  final VoidCallback onSettings;
  final VoidCallback onDaily;
  final VoidCallback onLeaderboard;
  final int coinBalance;
  final VoidCallback onCoins;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final glassBackground = palette.headerButtonBackground;
    final glassBorder = palette.headerButtonBorder;
    final glassForeground = palette.headerButtonForeground;
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          _HeaderActionButton(
            onPressed: onSettings,
            icon: Icons.settings,
            tooltip: strings.settings,
            color: glassForeground,
            backgroundColor: glassBackground,
            borderColor: glassBorder,
          ),
          const SizedBox(width: 10),
          _HeaderActionButton(
            onPressed: onDaily,
            icon: Icons.calendar_month_rounded,
            tooltip: strings.dailyChallenge,
            color: glassForeground,
            backgroundColor: glassBackground,
            borderColor: glassBorder,
          ),
          const SizedBox(width: 10),
          _HeaderActionButton(
            onPressed: onLeaderboard,
            icon: Icons.emoji_events_rounded,
            tooltip: strings.leaderboard,
            color: glassForeground,
            backgroundColor: glassBackground,
            borderColor: glassBorder,
          ),
          const Spacer(),
          _CoinBalancePill(balance: coinBalance, onTap: onCoins),
        ],
      ),
    );
  }
}

class _CoinBalancePill extends StatelessWidget {
  const _CoinBalancePill({required this.balance, required this.onTap});

  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final strings = AppStrings.of(context);
    final backgroundColor = palette.headerButtonBackground;
    final borderColor = palette.headerButtonBorder;
    final foregroundColor = palette.headerButtonForeground;
    return Semantics(
      button: true,
      label: '${strings.coins}: $balance',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: Ink(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: palette.isDark ? 0.16 : 0.055,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: palette.isDark ? 0 : 0.1,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 54),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xFFFFC928),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$balance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.34),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainMenuSettingsSheet extends StatefulWidget {
  const _MainMenuSettingsSheet({
    required this.onStats,
    required this.onPrivacy,
  });

  final VoidCallback onStats;
  final Future<void> Function() onPrivacy;

  @override
  State<_MainMenuSettingsSheet> createState() => _MainMenuSettingsSheetState();
}

class _MainMenuSettingsSheetState extends State<_MainMenuSettingsSheet> {
  final _languageController = LanguageController.instance;
  final _appearanceController = AppearanceController.instance;
  FeedbackSettings _settings = const FeedbackSettings(
    soundEnabled: true,
    hapticsEnabled: true,
    voiceGuideEnabled: true,
    wordAudioEnabled: true,
  );
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _languageController.addListener(_handleLanguageChanged);
    _appearanceController.addListener(_handleAppearanceChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _languageController.removeListener(_handleLanguageChanged);
    _appearanceController.removeListener(_handleAppearanceChanged);
    super.dispose();
  }

  void _handleLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAppearanceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSettings() async {
    final settings = await FeedbackService.instance.getSettings();
    if (mounted) {
      setState(() {
        _settings = settings;
        _loaded = true;
      });
    }
  }

  Future<void> _setSoundEnabled(bool enabled) async {
    setState(() => _settings = _settings.copyWith(soundEnabled: enabled));
    await FeedbackService.instance.setSoundEnabled(enabled);
  }

  Future<void> _setHapticsEnabled(bool enabled) async {
    setState(() => _settings = _settings.copyWith(hapticsEnabled: enabled));
    await FeedbackService.instance.setHapticsEnabled(enabled);
  }

  Future<void> _setVoiceGuideEnabled(bool enabled) async {
    setState(() => _settings = _settings.copyWith(voiceGuideEnabled: enabled));
    await FeedbackService.instance.setVoiceGuideEnabled(enabled);
  }

  Future<void> _setWordAudioEnabled(bool enabled) async {
    setState(() => _settings = _settings.copyWith(wordAudioEnabled: enabled));
    await FeedbackService.instance.setWordAudioEnabled(enabled);
  }

  Future<void> _setLanguage(String languageCode) async {
    await FeedbackService.instance.tap();
    await _languageController.setLocale(
      LanguagePreferenceStore.localeForCode(languageCode),
    );
  }

  Future<void> _setAppearance(AppearanceMode mode) async {
    await FeedbackService.instance.tap();
    await _appearanceController.setMode(mode);
  }

  Future<void> _setSkin(AppSkin skin) async {
    await FeedbackService.instance.tap();
    await _appearanceController.setSkin(skin);
  }

  Future<void> _replayGuide() async {
    await FeedbackService.instance.tap();
    await ProgressStore().resetGuideState();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final maxSheetHeight = mediaQuery.size.height - mediaQuery.padding.top - 12;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 430, maxHeight: maxSheetHeight),
        child: Material(
          color: Colors.transparent,
          child: ClaySurface(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottomInset),
            radius: 30,
            accentColor: ClayWorldColors.teal,
            backgroundColor: palette.sheetSurface,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.tileBorder,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SizedBox(
                        width: 92,
                        height: 80,
                        child: ClayAssetObject(
                          assetPath: 'assets/ui/clay/settings_gears.webp',
                          semanticLabel: strings.settings,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          strings.settings,
                          style: TextStyle(
                            color: palette.titleColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ClayPressable(
                        onTap: () => Navigator.of(context).pop(),
                        semanticLabel: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        color: palette.headerButtonBackground,
                        shadowColor: palette.headerButtonBorder,
                        radius: 18,
                        padding: EdgeInsets.zero,
                        child: SizedBox.square(
                          dimension: 40,
                          child: Icon(
                            Icons.close,
                            color: palette.headerButtonForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    opacity: _loaded ? 1 : 0.58,
                    duration: const Duration(milliseconds: 180),
                    child: Column(
                      children: [
                        _SettingsSwitchTile(
                          icon: Icons.volume_up,
                          label: strings.soundEffects,
                          value: _settings.soundEnabled,
                          onChanged: _setSoundEnabled,
                        ),
                        const SizedBox(height: 10),
                        _SettingsSwitchTile(
                          icon: Icons.vibration,
                          label: strings.haptics,
                          value: _settings.hapticsEnabled,
                          onChanged: _setHapticsEnabled,
                        ),
                        const SizedBox(height: 10),
                        _SettingsSwitchTile(
                          icon: Icons.record_voice_over,
                          label: strings.voiceGuide,
                          value: _settings.voiceGuideEnabled,
                          onChanged: _setVoiceGuideEnabled,
                          onPreview: _settings.voiceGuideEnabled
                              ? () {
                                  unawaited(
                                    VoiceGuideService.instance.playCue(
                                      VoiceGuideCue.gameIntro,
                                      interrupt: true,
                                    ),
                                  );
                                }
                              : null,
                        ),
                        const SizedBox(height: 10),
                        _SettingsSwitchTile(
                          icon: Icons.record_voice_over_rounded,
                          label: strings.wordPronunciation,
                          value: _settings.wordAudioEnabled,
                          onChanged: _setWordAudioEnabled,
                          onPreview: _settings.wordAudioEnabled
                              ? () {
                                  unawaited(
                                    VoiceGuideService.instance.playWord('LION'),
                                  );
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SettingsSkinTile(
                    label: strings.skin,
                    selectedSkin: _appearanceController.skin,
                    onChanged: _setSkin,
                  ),
                  const SizedBox(height: 10),
                  _SettingsParentSection(
                    label: strings.parentSettings,
                    children: [
                      _SettingsAppearanceTile(
                        label: strings.appearance,
                        selectedMode: _appearanceController.mode,
                        onChanged: _setAppearance,
                      ),
                      const SizedBox(height: 10),
                      _SettingsLanguageTile(
                        label: strings.language,
                        selectedCode: _languageController.selectedCode,
                        systemLabel: strings.systemLanguage,
                        onChanged: _setLanguage,
                      ),
                      const SizedBox(height: 10),
                      _SettingsActionTile(
                        icon: Icons.touch_app_rounded,
                        label: strings.replayGuide,
                        onTap: () {
                          unawaited(_replayGuide());
                        },
                      ),
                      const SizedBox(height: 10),
                      _SettingsActionTile(
                        icon: Icons.insights,
                        label: strings.viewStats,
                        onTap: widget.onStats,
                      ),
                      if (AdService.instance.isSupported) ...[
                        const SizedBox(height: 10),
                        _SettingsActionTile(
                          icon: Icons.privacy_tip_outlined,
                          label: strings.privacyOptions,
                          onTap: () {
                            unawaited(widget.onPrivacy());
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsParentSection extends StatelessWidget {
  const _SettingsParentSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return ClaySurface(
      padding: EdgeInsets.zero,
      radius: 22,
      accentColor: ClayWorldColors.coral,
      backgroundColor: palette.tileSurface,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.titleColor.withValues(
                alpha: palette.isDark ? 0.16 : 0.1,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: palette.titleColor,
              size: 21,
            ),
          ),
          iconColor: palette.titleColor,
          collapsedIconColor: palette.bodyColor,
          title: Text(
            label,
            style: TextStyle(
              color: palette.titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

class _SettingsLanguageTile extends StatelessWidget {
  const _SettingsLanguageTile({
    required this.label,
    required this.selectedCode,
    required this.systemLabel,
    required this.onChanged,
  });

  final String label;
  final String selectedCode;
  final String systemLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final options = [
      (code: 'system', label: systemLabel),
      (code: 'en', label: 'English'),
      (code: 'zh', label: '中文'),
      (code: 'ko', label: '한국어'),
    ];
    return ClaySurface(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 20,
      accentColor: ClayWorldColors.teal,
      backgroundColor: palette.tileSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language, color: palette.titleColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.bodyColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _SettingsChoiceChip(
                  label: option.label,
                  selected: selectedCode == option.code,
                  onTap: () => onChanged(option.code),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsAppearanceTile extends StatelessWidget {
  const _SettingsAppearanceTile({
    required this.label,
    required this.selectedMode,
    required this.onChanged,
  });

  final String label;
  final AppearanceMode selectedMode;
  final ValueChanged<AppearanceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final options = [
      (
        mode: AppearanceMode.system,
        label: strings.systemAppearance,
        icon: Icons.brightness_auto,
      ),
      (
        mode: AppearanceMode.light,
        label: strings.lightAppearance,
        icon: Icons.light_mode,
      ),
      (
        mode: AppearanceMode.dark,
        label: strings.darkAppearance,
        icon: Icons.dark_mode,
      ),
    ];
    return ClaySurface(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 20,
      accentColor: ClayWorldColors.yellow,
      backgroundColor: palette.tileSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette, color: palette.titleColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.bodyColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _SettingsChoiceChip(
                  label: option.label,
                  selected: selectedMode == option.mode,
                  onTap: () => onChanged(option.mode),
                  icon: option.icon,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSkinTile extends StatelessWidget {
  const _SettingsSkinTile({
    required this.label,
    required this.selectedSkin,
    required this.onChanged,
  });

  final String label;
  final AppSkin selectedSkin;
  final ValueChanged<AppSkin> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final options = [
      (
        skin: AppSkin.fresh,
        label: strings.freshSkin,
        icon: Icons.eco,
        color: const Color(0xFF2DB7B0),
      ),
      (
        skin: AppSkin.starry,
        label: strings.starrySkin,
        icon: Icons.nightlight_round,
        color: const Color(0xFF818CF8),
      ),
      (
        skin: AppSkin.candy,
        label: strings.candySkin,
        icon: Icons.auto_awesome,
        color: const Color(0xFFF472B6),
      ),
    ];
    final selectedColor = options
        .firstWhere((option) => option.skin == selectedSkin)
        .color;
    return ClaySurface(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 20,
      accentColor: selectedColor,
      backgroundColor: palette.tileSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.style, color: selectedColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.bodyColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _SettingsChoiceChip(
                  label: option.label,
                  selected: selectedSkin == option.skin,
                  onTap: () => onChanged(option.skin),
                  accentColor: option.color,
                  icon: option.icon,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsChoiceChip extends StatelessWidget {
  const _SettingsChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final color = accentColor ?? palette.titleColor;
    final backgroundColor = selected
        ? color.withValues(alpha: palette.isDark ? 0.16 : 0.12)
        : palette.iconSurface;
    final foregroundColor = selected ? color : palette.bodyColor;
    return ClayPressable(
      onTap: selected ? null : onTap,
      color: backgroundColor,
      shadowColor: selected
          ? color.withValues(alpha: 0.62)
          : palette.tileBorder,
      radius: 17,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 34,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: foregroundColor, size: 14),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onPreview,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return ClaySurface(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      radius: 20,
      accentColor: value ? ClayWorldColors.teal : palette.tileBorder,
      backgroundColor: palette.tileSurface,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.titleColor.withValues(
                alpha: palette.isDark ? 0.16 : 0.1,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: palette.titleColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.bodyColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (onPreview != null) ...[
            ClayPressable(
              onTap: onPreview,
              color: palette.iconSurface,
              shadowColor: palette.tileBorder,
              radius: 18,
              padding: EdgeInsets.zero,
              child: SizedBox.square(
                dimension: 38,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: palette.titleColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          _ClayToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return ClayPressable(
      onTap: onTap,
      color: palette.tileSurface,
      shadowColor: palette.tileBorder,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 38),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.titleColor.withValues(
                  alpha: palette.isDark ? 0.16 : 0.1,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: palette.titleColor, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.bodyColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: palette.titleColor.withValues(alpha: 0.82),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClayToggle extends StatelessWidget {
  const _ClayToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final track = value ? ClayWorldColors.teal : palette.iconSurface;
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 58,
          height: 34,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (value
                    ? ClayWorldColors.tealShadow
                    : palette.tileBorder),
                blurRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                color: ClayWorldColors.creamHighlight,
                shape: BoxShape.circle,
                border: Border.all(color: ClayWorldColors.creamEdge, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 2,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WordSearchLogo extends StatefulWidget {
  const _WordSearchLogo();

  @override
  State<_WordSearchLogo> createState() => _WordSearchLogoState();
}

class _ReferenceWordSearchLogo extends StatelessWidget {
  const _ReferenceWordSearchLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 310,
      height: 136,
      child: Image.asset(
        'assets/brand/home_word_search_logo.webp',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Word Search',
      ),
    );
  }
}

class _ReferenceHomeStage extends StatefulWidget {
  const _ReferenceHomeStage({
    required this.activeLevel,
    required this.onContinue,
    required this.onClassic,
  });

  final LevelDefinition activeLevel;
  final VoidCallback onContinue;
  final VoidCallback onClassic;

  @override
  State<_ReferenceHomeStage> createState() => _ReferenceHomeStageState();
}

class _ReferenceHomeStageState extends State<_ReferenceHomeStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return SizedBox(
      width: 330,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _motion,
            builder: (context, child) {
              final wave = math.sin(_motion.value * math.pi * 2);
              return Transform.translate(
                offset: Offset(0, wave * 5),
                child: Transform.rotate(angle: wave * 0.025, child: child),
              );
            },
            child: const _BulbCharacter(),
          ),
          const SizedBox(height: 8),
          _PrimaryMenuButton(
            label: strings.continueLearning,
            subtitle:
                '${strings.categoryName(widget.activeLevel.category.id)} · ${strings.levelButton(widget.activeLevel.themeLevel)}',
            color: palette.levelButtonColor,
            shadowColor: palette.levelButtonShadow,
            width: 220,
            height: 64,
            fontSize: 22,
            onTap: widget.onContinue,
          ),
          const SizedBox(height: 18),
          _PrimaryMenuButton(
            label: strings.chooseTheme,
            color: palette.classicButtonColor,
            shadowColor: palette.classicButtonShadow,
            width: 184,
            height: 52,
            fontSize: 20,
            onTap: widget.onClassic,
          ),
        ],
      ),
    );
  }
}

class _BulbCharacter extends StatelessWidget {
  const _BulbCharacter();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      height: 176,
      child: Image.asset(
        'assets/brand/home_bulb_mascot.webp',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Friendly lightbulb mascot',
      ),
    );
  }
}

class _WordSearchLogoState extends State<_WordSearchLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final progress = _motion.value;
        return SizedBox(
          width: 328,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 74,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _LogoText('W', index: 0, progress: progress),
                      const SizedBox(width: 7),
                      _LogoText('O', index: 1, progress: progress),
                      const SizedBox(width: 7),
                      _LogoText('R', index: 2, progress: progress),
                      const SizedBox(width: 7),
                      _LogoText('D', index: 3, progress: progress),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: _SearchLogoPill(progress: progress, palette: palette),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LogoText extends StatelessWidget {
  const _LogoText(this.text, {required this.index, required this.progress});

  final String text;
  final int index;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final wave = math.sin(progress * math.pi * 2 - index * 0.62);
    final bounce = math.max(0.0, wave) * 5.5;
    final colors = [
      palette.levelButtonColor,
      palette.classicButtonColor,
      palette.speedButtonColor,
      palette.hintColor,
    ];
    final tileColor = colors[index % colors.length];
    final rotation = math.sin(progress * math.pi * 2 + index) * 0.045;
    return Transform.translate(
      offset: Offset(0, -bounce),
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: palette.isDark ? 0.16 : 0.55),
                tileColor.withValues(alpha: palette.isDark ? 0.72 : 0.82),
              ],
            ),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: palette.isDark ? 0.28 : 0.72,
              ),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: tileColor.withValues(alpha: 0.24),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: palette.titleColor.withValues(alpha: 0.12),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: 43,
              height: 0.95,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: palette.titleColor.withValues(alpha: 0.22),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchLogoPill extends StatelessWidget {
  const _SearchLogoPill({required this.progress, required this.palette});

  final double progress;
  final WordSearchPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      width: 324,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.sheetSurface.withValues(alpha: palette.isDark ? 0.9 : 0.9),
            palette.headerButtonBackground.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: palette.isDark ? 0.34 : 0.86),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.classicButtonShadow.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: palette.isDark ? 0.08 : 0.5),
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SearchPillGlowPainter(progress, palette),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SearchPillLetter(
                  'S',
                  index: 0,
                  progress: progress,
                  palette: palette,
                ),
                _SearchPillLetter(
                  'E',
                  index: 1,
                  progress: progress,
                  palette: palette,
                ),
                _SearchPillLetter(
                  'A',
                  index: 2,
                  progress: progress,
                  palette: palette,
                ),
                _SearchPillLetter(
                  'R',
                  index: 3,
                  progress: progress,
                  palette: palette,
                ),
                _SearchPillLetter(
                  'C',
                  index: 4,
                  progress: progress,
                  palette: palette,
                ),
                _SearchPillLetter(
                  'H',
                  index: 5,
                  progress: progress,
                  palette: palette,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPillLetter extends StatelessWidget {
  const _SearchPillLetter(
    this.letter, {
    required this.index,
    required this.progress,
    required this.palette,
  });

  final String letter;
  final int index;
  final double progress;
  final WordSearchPalette palette;

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(progress * math.pi * 2 - index * 0.48);
    final lift = math.max(0.0, wave) * 4.5;
    final color = Color.lerp(
      palette.classicButtonColor,
      palette.speedButtonColor,
      (index / 5).clamp(0.0, 1.0) * 0.22,
    )!;
    final rotation = math.sin(progress * math.pi * 2 + index * 0.7) * 0.035;
    return Transform.translate(
      offset: Offset(0, -lift),
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 43,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: palette.isDark ? 0.62 : 0.82),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: palette.isDark ? 0.22 : 0.62,
              ),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            letter,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: 31,
              height: 0.98,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: palette.titleColor.withValues(alpha: 0.18),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchPillGlowPainter extends CustomPainter {
  const _SearchPillGlowPainter(this.progress, this.palette);

  final double progress;
  final WordSearchPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final x = -size.width * 0.3 + progress * size.width * 1.6;
    final rect = Rect.fromLTWH(x, 0, size.width * 0.22, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: palette.isDark ? 0.18 : 0.42),
          palette.hintColor.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.save();
    canvas.translate(x, 0);
    canvas.rotate(-0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, -8, size.width * 0.18, size.height + 16),
        const Radius.circular(99),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SearchPillGlowPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.palette != palette;
  }
}

class _BulbMascot extends StatefulWidget {
  const _BulbMascot();

  @override
  State<_BulbMascot> createState() => _BulbMascotState();
}

class _BulbMascotState extends State<_BulbMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final progress = _motion.value;
        final float = math.sin(progress * math.pi * 4) * 4.5;
        final breathe = 1 + math.sin(progress * math.pi * 4 + 1.2) * 0.012;
        return Transform.translate(
          offset: Offset(0, float),
          child: Transform.scale(
            scale: breathe,
            child: SizedBox(
              width: 296,
              height: 248,
              child: CustomPaint(
                painter: _BulbMascotPainter(
                  progress: progress,
                  palette: palette,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BulbMascotPainter extends CustomPainter {
  const _BulbMascotPainter({required this.progress, required this.palette});

  final double progress;
  final WordSearchPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.47);
    final pulse = (math.sin(progress * math.pi * 4) + 1) / 2;
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = palette.titleColor.withValues(
        alpha: palette.isDark ? 0.22 : 0.16,
      );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 250, height: 146),
      orbitPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 198, height: 110),
      orbitPaint..color = palette.classicButtonColor.withValues(alpha: 0.12),
    );

    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24)
      ..color = palette.hintColor.withValues(alpha: 0.22 + pulse * 0.08);
    canvas.drawCircle(center.translate(0, 10), 84 + pulse * 7, glowPaint);

    final letters = ['C', 'A', 'T', 'S', 'U', 'N', 'B', 'E'];
    final tileColors = [
      palette.levelButtonColor,
      palette.classicButtonColor,
      palette.speedButtonColor,
      palette.hintColor,
    ];
    final connector = Path();
    for (var i = 0; i < letters.length; i++) {
      final angle = progress * math.pi * 2 + i * math.pi * 2 / letters.length;
      final point = center.translate(
        math.cos(angle) * 119,
        math.sin(angle) * 67,
      );
      if (i == 0) {
        connector.moveTo(point.dx, point.dy);
      } else if (i < 4) {
        connector.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      connector,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = palette.hintColor.withValues(alpha: 0.2),
    );

    for (var i = 0; i < letters.length; i++) {
      final angle = progress * math.pi * 2 + i * math.pi * 2 / letters.length;
      final point = center.translate(
        math.cos(angle) * 119,
        math.sin(angle) * 67,
      );
      final color = tileColors[i % tileColors.length];
      final rect = Rect.fromCenter(center: point, width: 40, height: 40);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(math.sin(progress * math.pi * 2 + i) * 0.12);
      canvas.translate(-point.dx, -point.dy);
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: palette.isDark ? 0.14 : 0.55),
              color.withValues(alpha: palette.isDark ? 0.74 : 0.88),
            ],
          ).createShader(rect),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(
            alpha: palette.isDark ? 0.24 : 0.68,
          ),
      );
      _drawText(
        canvas,
        letters[i],
        point,
        fontSize: 21,
        color: Colors.white,
        weight: FontWeight.w900,
      );
      canvas.restore();
    }

    final bookTop = center.translate(0, -10);
    final leftPage = Path()
      ..moveTo(bookTop.dx - 84, bookTop.dy - 24)
      ..quadraticBezierTo(
        bookTop.dx - 42,
        bookTop.dy - 40,
        bookTop.dx,
        bookTop.dy - 14,
      )
      ..lineTo(bookTop.dx, bookTop.dy + 58)
      ..quadraticBezierTo(
        bookTop.dx - 42,
        bookTop.dy + 38,
        bookTop.dx - 92,
        bookTop.dy + 51,
      )
      ..close();
    final rightPage = Path()
      ..moveTo(bookTop.dx + 84, bookTop.dy - 24)
      ..quadraticBezierTo(
        bookTop.dx + 42,
        bookTop.dy - 40,
        bookTop.dx,
        bookTop.dy - 14,
      )
      ..lineTo(bookTop.dx, bookTop.dy + 58)
      ..quadraticBezierTo(
        bookTop.dx + 42,
        bookTop.dy + 38,
        bookTop.dx + 92,
        bookTop.dy + 51,
      )
      ..close();
    final leftBounds = leftPage.getBounds();
    final rightBounds = rightPage.getBounds();
    canvas.drawPath(
      leftPage,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.sheetSurface.withValues(
              alpha: palette.isDark ? 0.88 : 0.96,
            ),
            palette.classicButtonColor.withValues(
              alpha: palette.isDark ? 0.34 : 0.2,
            ),
          ],
        ).createShader(leftBounds),
    );
    canvas.drawPath(
      rightPage,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            palette.sheetSurface.withValues(
              alpha: palette.isDark ? 0.88 : 0.96,
            ),
            palette.speedButtonColor.withValues(
              alpha: palette.isDark ? 0.34 : 0.2,
            ),
          ],
        ).createShader(rightBounds),
    );
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: palette.isDark ? 0.22 : 0.72);
    canvas.drawPath(leftPage, outline);
    canvas.drawPath(rightPage, outline);
    canvas.drawLine(
      bookTop.translate(0, -10),
      bookTop.translate(0, 58),
      outline..color = palette.titleColor.withValues(alpha: 0.18),
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = bookTop.dy + 4 + i * 18;
      linePaint.color =
          (i.isEven ? palette.classicButtonColor : palette.levelButtonColor)
              .withValues(alpha: 0.62);
      canvas.drawLine(
        Offset(bookTop.dx - 62, y),
        Offset(bookTop.dx - 18, y + 6),
        linePaint,
      );
      linePaint.color =
          (i.isEven ? palette.speedButtonColor : palette.hintColor).withValues(
            alpha: 0.62,
          );
      canvas.drawLine(
        Offset(bookTop.dx + 18, y + 6),
        Offset(bookTop.dx + 62, y),
        linePaint,
      );
    }

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center.translate(0, 68), width: 116, height: 34),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = palette.titleColor.withValues(
          alpha: palette.isDark ? 0.72 : 0.78,
        ),
    );
    _drawText(
      canvas,
      'FIND',
      badgeRect.outerRect.center,
      fontSize: 17,
      color: Colors.white,
      weight: FontWeight.w900,
    );

    final sparkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32 + pulse * 0.28)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var i = 0; i < 6; i++) {
      final angle = -progress * math.pi * 2 + i * math.pi / 3;
      final point = center.translate(
        math.cos(angle) * 136,
        math.sin(angle) * 82,
      );
      final length = 3.5 + (i.isEven ? pulse : 1 - pulse) * 3;
      canvas.drawLine(
        point.translate(-length, 0),
        point.translate(length, 0),
        sparkPaint,
      );
      canvas.drawLine(
        point.translate(0, -length),
        point.translate(0, length),
        sparkPaint,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    required FontWeight weight,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BulbMascotPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.palette != palette;
  }
}

class _PrimaryMenuButton extends StatefulWidget {
  const _PrimaryMenuButton({
    required this.label,
    required this.color,
    required this.shadowColor,
    required this.onTap,
    this.subtitle,
    this.leadingIcon,
    this.width = 300,
    this.height = 64,
    this.fontSize = 33,
  });

  final String label;
  final String? subtitle;
  final IconData? leadingIcon;
  final Color color;
  final Color shadowColor;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double fontSize;

  @override
  State<_PrimaryMenuButton> createState() => _PrimaryMenuButtonState();
}

class _PrimaryMenuButtonState extends State<_PrimaryMenuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor.withValues(alpha: 0.36),
                blurRadius: 12,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.44),
                blurRadius: 3,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 22,
              vertical: subtitle == null ? 0 : 7,
            ),
            child: subtitle == null
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          Icon(
                            widget.leadingIcon,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 7),
                        ],
                        Text(
                          widget.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            shadows: const [
                              Shadow(
                                color: Color(0x24000000),
                                blurRadius: 2,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.fontSize - 5,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            shadows: const [
                              Shadow(
                                color: Color(0x24000000),
                                blurRadius: 2,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _CampaignHomePanel extends StatelessWidget {
  const _CampaignHomePanel({
    required this.level,
    required this.category,
    required this.difficulty,
    required this.completed,
    required this.onTap,
  });

  final int level;
  final WordCategory category;
  final Difficulty difficulty;
  final int completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return SizedBox(
      width: 340,
      height: 246,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 188,
            child: Material(
              color: palette.sheetSurface,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              elevation: 5,
              shadowColor: palette.titleColor.withValues(alpha: 0.2),
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(category.assetPath, fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.02),
                            Colors.black.withValues(alpha: 0.12),
                            const Color(0xC7233D40),
                          ],
                          stops: const [0, 0.52, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CategoryThumbnail(
                              category: category,
                              size: 20,
                              borderRadius: 5,
                              showBorder: false,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              strings.categoryName(category.id),
                              style: TextStyle(
                                color: palette.titleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$completed/$levelsPerTheme',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 23,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              strings.categoryDescription(category.id),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                shadows: const [
                                  Shadow(color: Colors.black45, blurRadius: 6),
                                ],
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: _PrimaryMenuButton(
              label: strings.levelButton(level),
              subtitle:
                  '${strings.modeLabel(GameMode.classic)} · ${strings.difficultyLabel(difficulty)}',
              leadingIcon: Icons.play_arrow_rounded,
              color: palette.levelButtonColor,
              shadowColor: palette.levelButtonShadow,
              width: 316,
              height: 78,
              fontSize: 29,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _MainMenuActionButtons extends StatelessWidget {
  const _MainMenuActionButtons({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftIcon,
    required this.rightIcon,
    required this.onLeft,
    required this.onRight,
  });

  final String leftLabel;
  final String rightLabel;
  final IconData leftIcon;
  final IconData rightIcon;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return SizedBox(
      width: 300,
      child: Row(
        children: [
          Expanded(
            child: _PrimaryMenuButton(
              label: leftLabel,
              color: palette.classicButtonColor,
              shadowColor: palette.classicButtonShadow,
              width: double.infinity,
              height: 62,
              fontSize: 20,
              leadingIcon: leftIcon,
              onTap: onLeft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PrimaryMenuButton(
              label: rightLabel,
              color: palette.speedButtonColor,
              shadowColor: palette.speedButtonShadow,
              width: double.infinity,
              height: 62,
              fontSize: 20,
              leadingIcon: rightIcon,
              onTap: onRight,
            ),
          ),
        ],
      ),
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({
    required this.onStart,
    required this.onDailyChallenge,
    this.initialMode = GameMode.classic,
    this.lockedMode,
    this.onBackToMain,
    this.onRefreshReady,
    super.key,
  });

  final void Function(
    WordCategory category,
    Difficulty difficulty,
    GameMode mode,
  )
  onStart;
  final Future<void> Function() onDailyChallenge;
  final GameMode initialMode;
  final GameMode? lockedMode;
  final VoidCallback? onBackToMain;
  final ValueChanged<VoidCallback>? onRefreshReady;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _progressStore = ProgressStore();
  final _dailyChallengeStore = const DailyChallengeStore();
  Difficulty _difficulty = Difficulty.medium;
  GameMode _mode = GameMode.classic;
  DailyChallenge? _dailyChallenge;
  Map<String, int> _progress = {};
  int _listRevision = 0;

  @override
  void initState() {
    super.initState();
    _mode = widget.lockedMode ?? widget.initialMode;
    _loadProgress();
    widget.onRefreshReady?.call(_loadProgress);
  }

  Future<void> _loadProgress() async {
    final progress = await _progressStore.getDifficultyProgress(
      _difficulty.storageName,
    );
    final dailyChallenge = widget.lockedMode == null
        ? await _dailyChallengeStore.getToday()
        : null;
    if (mounted) {
      setState(() {
        _progress = progress;
        _dailyChallenge = dailyChallenge;
        _listRevision += 1;
      });
    }
  }

  void _setMode(GameMode mode) {
    if (widget.lockedMode != null) {
      return;
    }
    if (_mode == mode) {
      return;
    }
    setState(() {
      _mode = mode;
      _listRevision += 1;
    });
    unawaited(
      VoiceGuideService.instance.playCue(
        mode == GameMode.classic
            ? VoiceGuideCue.chooseClassic
            : VoiceGuideCue.chooseSpeed,
        interrupt: true,
        minInterval: const Duration(seconds: 4),
      ),
    );
  }

  void _setDifficulty(Difficulty difficulty) {
    if (_difficulty == difficulty) {
      return;
    }
    setState(() {
      _difficulty = difficulty;
      _progress = {};
      _listRevision += 1;
    });
    unawaited(
      VoiceGuideService.instance.playCue(
        VoiceGuideCue.chooseDifficulty,
        interrupt: false,
        minInterval: const Duration(seconds: 5),
        skipIfBusy: true,
      ),
    );
    _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    final showCrossEntryPanel = widget.lockedMode == null;
    final palette = WordSearchPalette.of(context);
    return Scaffold(
      body: PlayfulPageBackground(
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HomeHeader(
                              mode: _mode,
                              difficulty: _difficulty,
                              onBackToMain: widget.onBackToMain,
                            ),
                            if (showCrossEntryPanel) ...[
                              const SizedBox(height: 8),
                              _DailyChallengePanel(
                                challenge: _dailyChallenge,
                                onTap: widget.onDailyChallenge,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _PlayControlPanel(
                              mode: _mode,
                              difficulty: _difficulty,
                              lockedMode: widget.lockedMode,
                              onModeChanged: _setMode,
                              onDifficultyChanged: _setDifficulty,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GameRefreshIndicator(
                          onRefresh: _loadProgress,
                          color: palette.refreshAccent,
                          icon: Icons.lightbulb,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            reverseDuration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.025),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: ListView.separated(
                              key: ValueKey(
                                '${_mode.storageName}-${_difficulty.storageName}-$_listRevision',
                              ),
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                24,
                                0,
                                24,
                                148 + MediaQuery.paddingOf(context).bottom,
                              ),
                              itemCount: wordCategories.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final category = wordCategories[index];
                                return _StaggeredEntrance(
                                  key: ValueKey(
                                    '${category.id}-${_mode.storageName}-${_difficulty.storageName}-$_listRevision',
                                  ),
                                  delay: Duration(milliseconds: 45 * index),
                                  child: CategoryCard(
                                    category: category,
                                    difficulty: _difficulty,
                                    mode: _mode,
                                    doneCount: _progress[category.id] ?? 0,
                                    onTap: () => widget.onStart(
                                      category,
                                      _difficulty,
                                      _mode,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const _HomeBannerAd(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinWalletSheet extends StatelessWidget {
  const _CoinWalletSheet({required this.balance, required this.canWatchVideo});

  final int balance;
  final bool canWatchVideo;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final surface = Color.alphaBlend(
      palette.titleColor.withValues(alpha: palette.isDark ? 0.12 : 0.075),
      palette.sheetSurface,
    );
    final detailSurface = palette.titleColor.withValues(
      alpha: palette.isDark ? 0.14 : 0.075,
    );
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surface, palette.tileSurface],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: palette.headerButtonBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.34 : 0.16),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.mutedColor.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const _CoinWalletMedallion(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.coinWallet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.titleColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: balance),
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Text(
                                strings.coinBalance(value),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.titleColor,
                                  fontSize: 22,
                                  height: 1.08,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        style: IconButton.styleFrom(
                          backgroundColor: detailSurface,
                          foregroundColor: palette.titleColor,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: detailSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.titleColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: palette.refreshAccent,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            strings.earnCoinsByPlaying,
                            style: TextStyle(
                              color: palette.bodyColor,
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canWatchVideo) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop('video'),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.levelButtonColor,
                          foregroundColor: palette.headerButtonForeground,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        label: Text(strings.watchForCoins),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinWalletMedallion extends StatelessWidget {
  const _CoinWalletMedallion();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFDA4A), Color(0xFFFFAA19)],
        ),
        border: Border.all(color: const Color(0xFFFFE993), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB321).withValues(alpha: 0.34),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.62),
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.monetization_on_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: ExcludeSemantics(
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: palette.isDark ? 0.16 : 0.055,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: palette.isDark ? 0 : 0.1,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Center(child: Icon(icon, size: 21, color: color)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultySegment extends StatelessWidget {
  const _DifficultySegment({required this.selected, required this.onChanged});

  final Difficulty selected;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFF8FEFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: Difficulty.values
            .map((difficulty) {
              final isSelected = selected == difficulty;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: InkWell(
                    onTap: () => onChanged(difficulty),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? difficulty.color
                            : palette.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? difficulty.color
                              : palette.tileBorder,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: difficulty.color.withValues(alpha: 0.24),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _difficultyIcon(difficulty),
                            size: 13,
                            color: isSelected
                                ? Colors.white
                                : palette.mutedColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              strings.difficultyShortLabel(difficulty),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : palette.mutedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _PlayControlPanel extends StatelessWidget {
  const _PlayControlPanel({
    required this.mode,
    required this.difficulty,
    required this.lockedMode,
    required this.onModeChanged,
    required this.onDifficultyChanged,
  });

  final GameMode mode;
  final Difficulty difficulty;
  final GameMode? lockedMode;
  final ValueChanged<GameMode> onModeChanged;
  final ValueChanged<Difficulty> onDifficultyChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final locked = lockedMode;
    final palette = WordSearchPalette.of(context);
    if (locked != null) {
      return Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: palette.isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.tileBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _DifficultySegment(
          selected: difficulty,
          onChanged: onDifficultyChanged,
        ),
      );
    }

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.tileBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  child: _ModeSegmentButton(
                    selected: mode == GameMode.classic,
                    icon: Icons.star,
                    label: strings.modeLabel(GameMode.classic),
                    selectedColor: palette.classicButtonColor,
                    onTap: () => onModeChanged(GameMode.classic),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _ModeSegmentButton(
                    selected: mode == GameMode.speed,
                    icon: Icons.timer,
                    label: strings.modeLabel(GameMode.speed),
                    selectedColor: palette.speedButtonColor,
                    onTap: () => onModeChanged(GameMode.speed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 6,
            child: _DifficultySegment(
              selected: difficulty,
              onChanged: onDifficultyChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegmentButton extends StatelessWidget {
  const _ModeSegmentButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.selectedColor,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        height: 44,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? selectedColor
              : palette.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? selectedColor : palette.tileBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : palette.mutedColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : palette.mutedColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyChallengePanel extends StatelessWidget {
  const _DailyChallengePanel({required this.challenge, required this.onTap});

  final DailyChallenge? challenge;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final current = challenge;
    final strings = AppStrings.of(context);
    const color = Color(0xFFFF7A69);
    final completed = current?.completedToday == true;
    final enabled = current != null && !completed;
    final dateLabel = current == null
        ? '--/--'
        : _dailyDateLabel(current.dateKey);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: !enabled
            ? null
            : () {
                onTap();
              },
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF8A77), Color(0xFFFFB55C), Color(0xFFFFF0D6)],
              stops: [0, 0.58, 1],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.66)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _DailyStripePainter(color)),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const ClayAssetObject(
                            assetPath: 'assets/ui/clay/daily_rewards.webp',
                          ),
                          Positioned(
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: Colors.white),
                              ),
                              child: Text(
                                completed ? strings.done : dateLabel,
                                style: const TextStyle(
                                  color: Color(0xFF155E75),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  strings.todayPuzzle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              if (completed) ...[
                                const SizedBox(width: 7),
                                _DailyStatusPill(
                                  icon: Icons.check,
                                  label: strings.done,
                                  color: const Color(0xFF86EFAC),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: current == null
                                ? Text(
                                    strings.preparingToday,
                                    key: const ValueKey('daily-loading'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )
                                : Row(
                                    key: ValueKey(current.dateKey),
                                    children: [
                                      CategoryThumbnail(
                                        category: current.category,
                                        size: 22,
                                        borderRadius: 6,
                                        showBorder: false,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${strings.categoryName(current.category.id)} · ${strings.difficultyLabel(current.difficulty)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DailyStatusPill(
                      icon: Icons.local_fire_department,
                      label: strings.dailyStreak(current?.streak ?? 0),
                      color: const Color(0xFFFACC15),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.32),
                            Colors.white.withValues(alpha: 0.82),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        completed ? Icons.check_rounded : Icons.play_arrow,
                        color: completed
                            ? Color(0xFF22C55E)
                            : Color(0xFF0891B2),
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dailyDateLabel(String dateKey) {
    if (dateKey.length != 8) {
      return '--/--';
    }
    final month = int.tryParse(dateKey.substring(4, 6)) ?? 0;
    final day = int.tryParse(dateKey.substring(6, 8)) ?? 0;
    return '$month/$day';
  }
}

class _DailyStatusPill extends StatelessWidget {
  const _DailyStatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyStripePainter extends CustomPainter {
  const _DailyStripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.16);
    for (var x = -size.height; x < size.width; x += 28) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DailyStripePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _HomeBannerAd extends StatefulWidget {
  const _HomeBannerAd();

  @override
  State<_HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends State<_HomeBannerAd> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  int? _loadedWidth;
  DateTime? _nextRetryAt;
  bool _isLoaded = false;
  bool _isLoading = false;
  int _failureCount = 0;

  @override
  void initState() {
    super.initState();
    AdService.instance.addListener(_handleAdServiceChanged);
  }

  @override
  void dispose() {
    AdService.instance.removeListener(_handleAdServiceChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  void _handleAdServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAd(int width) async {
    if (_isLoading ||
        _loadedWidth == width ||
        !AdService.instance.isSupported ||
        !AdService.instance.initialized) {
      return;
    }
    final nextRetryAt = _nextRetryAt;
    if (nextRetryAt != null && DateTime.now().isBefore(nextRetryAt)) {
      return;
    }

    _isLoading = true;
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted) {
      _isLoading = false;
      return;
    }
    if (size == null) {
      setState(() => _isLoading = false);
      return;
    }

    final previousAd = _bannerAd;
    final bannerAd = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          previousAd?.dispose();
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _adSize = size;
            _loadedWidth = width;
            _nextRetryAt = null;
            _isLoaded = true;
            _isLoading = false;
            _failureCount = 0;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Home banner ad failed: ${error.code} ${error.message}');
          ad.dispose();
          if (mounted) {
            final retrySeconds = switch (_failureCount) {
              0 => 10,
              1 => 30,
              2 => 60,
              _ => 120,
            };
            setState(() {
              _isLoaded = false;
              _isLoading = false;
              _loadedWidth = null;
              _failureCount += 1;
              _nextRetryAt = DateTime.now().add(
                Duration(seconds: retrySeconds),
              );
            });
          }
        },
      ),
    );
    await bannerAd.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService.instance.isSupported || !AdService.instance.initialized) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.truncate()
            : MediaQuery.sizeOf(context).width.truncate();
        final adWidth = (width - 24).clamp(320, 640);
        _loadAd(adWidth);

        final bannerAd = _bannerAd;
        final adSize = _adSize;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final height = _isLoaded && bannerAd != null && adSize != null
            ? adSize.height + 18 + bottomInset
            : 0.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: height,
          padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + bottomInset),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFD8F1EC).withValues(alpha: 0.72),
              ),
            ),
          ),
          child: _isLoaded && bannerAd != null && adSize != null
              ? Center(
                  child: SizedBox(
                    width: adSize.width.toDouble(),
                    height: adSize.height.toDouble(),
                    child: AdWidget(ad: bannerAd),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({
    required this.delay,
    required this.child,
    super.key,
  });

  final Duration delay;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(-0.08, 0),
      end: Offset.zero,
    ).animate(curved);
    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.mode,
    required this.difficulty,
    required this.onBackToMain,
  });

  final GameMode mode;
  final Difficulty difficulty;
  final VoidCallback? onBackToMain;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final backToMain = onBackToMain;
    final modeColor = mode == GameMode.classic
        ? palette.classicButtonColor
        : palette.speedButtonColor;
    final modeIcon = mode == GameMode.classic ? Icons.star : Icons.timer;
    return SizedBox(
      height: 58,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (backToMain == null)
            _ModeHeaderBadge(icon: modeIcon, color: modeColor)
          else
            _HeaderActionButton(
              onPressed: backToMain,
              icon: Icons.arrow_back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              color: palette.headerButtonForeground,
              backgroundColor: palette.headerButtonBackground,
              borderColor: palette.headerButtonBorder,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.modeTitle(mode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.pageForegroundColor,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${strings.chooseCategory} · ${strings.difficultyLabel(difficulty)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.pageMutedForegroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (backToMain != null) ...[
            const SizedBox(width: 10),
            _ModeHeaderBadge(icon: modeIcon, color: modeColor),
          ],
        ],
      ),
    );
  }
}

class _ModeHeaderBadge extends StatelessWidget {
  const _ModeHeaderBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutBack,
      builder: (context, pulse, child) {
        return Transform.scale(
          scale: 0.96 + pulse * 0.04,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.82),
                  color.withValues(alpha: 0.5),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18 + pulse * 0.12),
                  blurRadius: 12 + pulse * 8,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 27),
          ),
        );
      },
    );
  }
}

IconData _difficultyIcon(Difficulty difficulty) => switch (difficulty) {
  Difficulty.easy => Icons.star,
  Difficulty.medium => Icons.bolt,
  Difficulty.hard => Icons.local_fire_department,
};
