import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../l10n/app_strings.dart';
import '../../data/local_stats_store.dart';
import '../../data/word_review_store.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../../domain/puzzle_engine.dart';
import '../../domain/word_learning.dart';
import '../widgets/category_thumbnail.dart';
import '../widgets/clay_ui.dart';
import '../widgets/game_refresh_indicator.dart';
import '../widgets/theme_scene_assets.dart';
import 'word_review_screen.dart';

class LocalStatsScreen extends StatefulWidget {
  const LocalStatsScreen({super.key});

  @override
  State<LocalStatsScreen> createState() => _LocalStatsScreenState();
}

class _LocalStatsScreenState extends State<LocalStatsScreen> {
  final _store = const LocalStatsStore();
  final _wordReviewStore = const WordReviewStore();
  late Future<_StatsSnapshot> _statsFuture = _loadSnapshot();

  Future<void> _refresh() async {
    final statsFuture = _loadSnapshot();
    setState(() {
      _statsFuture = statsFuture;
    });
    await statsFuture;
  }

  Future<_StatsSnapshot> _loadSnapshot() async {
    final results = await Future.wait<Object>([
      _store.getStats(),
      _wordReviewStore.getRecords(),
    ]);
    return _StatsSnapshot(
      stats: results[0] as LocalStats,
      learnedWords: results[1] as List<LearnedWordRecord>,
    );
  }

  void _openReview() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const WordReviewScreen()))
        .then((_) {
          if (mounted) {
            _refresh();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Scaffold(
      body: ClaySceneBackdrop(
        assetPath: clayStatsSceneAsset,
        foregroundGradient: palette.isDark,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ClayPageHeader(
                      title: strings.myStats,
                      onBack: () => Navigator.of(context).pop(),
                      onAction: _refresh,
                      actionIcon: Icons.refresh_rounded,
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<_StatsSnapshot>(
                      future: _statsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFFB84D),
                            ),
                          );
                        }
                        final statsSnapshot = snapshot.data;
                        if (statsSnapshot == null) {
                          return Center(
                            child: Text(
                              strings.noStatsYet,
                              style: TextStyle(
                                color: palette.pageMutedForegroundColor,
                              ),
                            ),
                          );
                        }
                        final stats = statsSnapshot.stats;
                        return GameRefreshIndicator(
                          onRefresh: _refresh,
                          color: palette.refreshAccent,
                          icon: Icons.insights,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              42 + MediaQuery.paddingOf(context).bottom,
                            ),
                            children: [
                              _FavoriteCategoryCard(stats: stats),
                              const SizedBox(height: 12),
                              _LearningOverviewCard(
                                records: statsSnapshot.learnedWords,
                                onReview: _openReview,
                              ),
                              const SizedBox(height: 12),
                              _RewardOverviewCard(stats: stats),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.42,
                                children: [
                                  _StatTile(
                                    icon: Icons.spellcheck,
                                    label: strings.wordsFound,
                                    value: '${stats.totalWordsFound}',
                                    color: const Color(0xFF38BDF8),
                                  ),
                                  _StatTile(
                                    icon: Icons.flag_circle,
                                    label: strings.gamesDone,
                                    value: '${stats.gamesCompleted}',
                                    color: const Color(0xFF22C55E),
                                  ),
                                  _StatTile(
                                    icon: Icons.today,
                                    label: strings.dailyDone,
                                    value: '${stats.dailyCompleted}',
                                    color: const Color(0xFFFACC15),
                                  ),
                                  _StatTile(
                                    icon: Icons.timer,
                                    label: strings.bestTime,
                                    value: stats.bestClassicSeconds == null
                                        ? '--'
                                        : formatSeconds(
                                            stats.bestClassicSeconds!,
                                          ),
                                    color: const Color(0xFFFB7185),
                                  ),
                                  _StatTile(
                                    icon: Icons.speed,
                                    label: strings.bestSpeed,
                                    value: stats.bestSpeedScore == null
                                        ? '--'
                                        : '${stats.bestSpeedScore}',
                                    color: const Color(0xFFA78BFA),
                                  ),
                                  _StatTile(
                                    icon: Icons.category,
                                    label: strings.themesPlayed,
                                    value:
                                        '${stats.categoryCompletions.length}',
                                    color: const Color(0xFFF97316),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
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

class _StatsSnapshot {
  const _StatsSnapshot({required this.stats, required this.learnedWords});

  final LocalStats stats;
  final List<LearnedWordRecord> learnedWords;
}

class _FavoriteCategoryCard extends StatelessWidget {
  const _FavoriteCategoryCard({required this.stats});

  final LocalStats stats;

  @override
  Widget build(BuildContext context) {
    final category = stats.favoriteCategory;
    final color = category?.accentColor ?? const Color(0xFFFACC15);
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return ClaySurface(
      padding: const EdgeInsets.all(18),
      radius: 22,
      accentColor: color,
      backgroundColor: palette.sheetSurface,
      child: Row(
        children: [
          if (category != null)
            CategoryThumbnail(category: category, size: 58, borderRadius: 16)
          else
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: palette.iconSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.tileBorder),
              ),
              child: Icon(
                Icons.category_outlined,
                color: palette.mutedColor,
                size: 28,
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.favoriteTheme,
                  style: TextStyle(
                    color: palette.mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  category == null
                      ? strings.playAGame
                      : strings.categoryName(category.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.titleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category == null
                      ? strings.startTracking
                      : strings.completedRounds(
                          stats.categoryCompletions[category.id] ?? 0,
                        ),
                  style: TextStyle(color: palette.mutedColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningOverviewCard extends StatelessWidget {
  const _LearningOverviewCard({required this.records, required this.onReview});

  final List<LearnedWordRecord> records;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final favoriteCount = records.where((record) => record.isFavorite).length;
    final recentRecords = records.take(5).toList(growable: false);
    return ClaySurface(
      padding: const EdgeInsets.all(16),
      radius: 20,
      accentColor: ClayWorldColors.yellow,
      backgroundColor: palette.sheetSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_rounded, color: palette.hintColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.learning,
                  style: TextStyle(
                    color: palette.titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ClayPressable(
                onTap: onReview,
                color: ClayWorldColors.yellow,
                shadowColor: ClayWorldColors.yellowShadow,
                radius: 15,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 15,
                      color: ClayWorldColors.deepPurple,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      strings.reviewWords,
                      style: const TextStyle(
                        color: ClayWorldColors.deepPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LearningStatPill(
                  icon: Icons.spellcheck_rounded,
                  label: strings.learnedWords,
                  value: '${records.length}',
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _LearningStatPill(
                  icon: Icons.star_rounded,
                  label: strings.favoriteWords,
                  value: '$favoriteCount',
                  color: const Color(0xFFFFB84D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            strings.recentWords,
            style: TextStyle(
              color: palette.mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (recentRecords.isEmpty)
            Text(
              strings.noLearnedWordsYet,
              style: TextStyle(
                color: palette.mutedColor,
                fontSize: 12,
                height: 1.35,
              ),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final record in recentRecords)
                  _RecentWordPill(record: record),
              ],
            ),
        ],
      ),
    );
  }
}

class _LearningStatPill extends StatelessWidget {
  const _LearningStatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.mutedColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: palette.titleColor,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentWordPill extends StatelessWidget {
  const _RecentWordPill({required this.record});

  final LearnedWordRecord record;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final category = _categoryFor(record.categoryId);
    final color = category?.accentColor ?? palette.hintColor;
    final learning = wordLearningEntryFor(record.word);
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.17 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (record.isFavorite) ...[
            const Icon(Icons.star_rounded, color: Color(0xFFFFB84D), size: 13),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 116),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.titleColor,
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  learning.meaningFor(strings.locale.languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedColor,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardOverviewCard extends StatelessWidget {
  const _RewardOverviewCard({required this.stats});

  final LocalStats stats;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final unlockedCount = stats.unlockedBadgeIds.length;
    return ClaySurface(
      padding: const EdgeInsets.all(16),
      radius: 20,
      accentColor: ClayWorldColors.coral,
      backgroundColor: palette.sheetSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: palette.hintColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.rewards,
                  style: TextStyle(
                    color: palette.titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _RewardCounter(
                icon: Icons.star_rounded,
                label: '${stats.totalStars}',
                color: const Color(0xFFFACC15),
              ),
              const SizedBox(width: 7),
              _RewardCounter(
                icon: Icons.workspace_premium,
                label: '$unlockedCount/${rewardBadges.length}',
                color: const Color(0xFF38BDF8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rewardBadges.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final badge = rewardBadges[index];
                final unlocked = stats.unlockedBadgeIds.contains(badge.id);
                return _BadgeChip(badge: badge, unlocked: unlocked);
              },
            ),
          ),
          if (unlockedCount == 0) ...[
            const SizedBox(height: 9),
            Text(
              strings.noBadgesYet,
              style: TextStyle(color: palette.mutedColor, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardCounter extends StatelessWidget {
  const _RewardCounter({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge, required this.unlocked});

  final RewardBadgeDefinition badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final color = unlocked ? const Color(0xFFFFB84D) : const Color(0xFF94A3B8);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 96,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked
            ? const Color(0xFFFFB84D).withValues(alpha: 0.18)
            : palette.tileSurface.withValues(
                alpha: palette.isDark ? 0.7 : 0.72,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? const Color(0xFFFFB84D).withValues(alpha: 0.36)
              : palette.tileBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            unlocked ? _rewardBadgeIcon(badge.id) : Icons.lock_outline_rounded,
            color: color,
            size: 22,
          ),
          const Spacer(),
          Text(
            strings.badgeName(badge.id),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked ? palette.titleColor : const Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            strings.badgeDescription(badge.id),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked ? palette.mutedColor : const Color(0xFFB6C5CA),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _rewardBadgeIcon(String id) => switch (id) {
  'first_win' => Icons.flag_rounded,
  'star_collector' => Icons.star_rounded,
  'daily_starter' => Icons.calendar_month_rounded,
  'theme_explorer' => Icons.explore_rounded,
  'speed_runner' => Icons.bolt_rounded,
  'word_hunter' => Icons.search_rounded,
  _ => Icons.workspace_premium_rounded,
};

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return ClaySurface(
      padding: const EdgeInsets.all(14),
      radius: 18,
      accentColor: color,
      backgroundColor: palette.sheetSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.titleColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.mutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

WordCategory? _categoryFor(String id) {
  for (final category in wordCategories) {
    if (category.id == id) {
      return category;
    }
  }
  return null;
}
