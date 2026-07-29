import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../l10n/app_strings.dart';
import '../../data/daily_challenge_store.dart';
import '../widgets/category_thumbnail.dart';
import '../widgets/clay_ui.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({required this.challenge, super.key});

  final DailyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Scaffold(
      body: ClaySceneBackdrop(
        assetPath: 'assets/ui/clay/scenes/daily-world-v1.webp',
        foregroundGradient: palette.isDark,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ClayPageHeader(
                      title: strings.dailyChallenge,
                      titleFontSize: 27,
                      onBack: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        8,
                        18,
                        28 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        children: [
                          _ChallengeSummary(challenge: challenge),
                          const SizedBox(height: 10),
                          _PromotionalRewardBoard(challenge: challenge),
                          const SizedBox(height: 8),
                          _RewardStats(challenge: challenge),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ClayPressable(
                              onTap: () => Navigator.of(context).pop(true),
                              color: challenge.completedToday
                                  ? ClayWorldColors.teal
                                  : ClayWorldColors.coral,
                              shadowColor: challenge.completedToday
                                  ? ClayWorldColors.tealShadow
                                  : ClayWorldColors.coralShadow,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    challenge.completedToday
                                        ? Icons.emoji_events_rounded
                                        : Icons.play_arrow_rounded,
                                    color: ClayWorldColors.creamHighlight,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      challenge.completedToday
                                          ? strings.viewLeaderboard
                                          : strings.todayPuzzle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: ClayWorldColors.creamHighlight,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _ChallengeSummary extends StatelessWidget {
  const _ChallengeSummary({required this.challenge});

  final DailyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CategoryThumbnail(
          category: challenge.category,
          size: 34,
          borderRadius: 12,
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            '${strings.categoryName(challenge.category.id)} · ${strings.difficultyLabel(challenge.difficulty)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PromotionalRewardBoard extends StatelessWidget {
  const _PromotionalRewardBoard({required this.challenge});

  final DailyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final state = challenge.completedToday ? 'complete' : 'active';
    return AspectRatio(
      aspectRatio: 970 / 780,
      child: Image.asset(
        'assets/ui/clay/daily_reward_board_weekday_${challenge.weekday}_$state.webp',
        key: const ValueKey('daily-reward-board'),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _RewardStats extends StatelessWidget {
  const _RewardStats({required this.challenge});

  final DailyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              color: ClayWorldColors.coral,
              size: 23,
            ),
            const SizedBox(width: 6),
            Text(
              strings.dailyStreak(challenge.streak),
              style: TextStyle(
                color: palette.bodyColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on_rounded,
              color: ClayWorldColors.yellowShadow,
              size: 22,
            ),
            const SizedBox(width: 5),
            Text(
              strings.coinReward(80),
              style: TextStyle(
                color: palette.bodyColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
