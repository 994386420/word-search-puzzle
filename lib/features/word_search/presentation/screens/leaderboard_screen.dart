import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../l10n/app_strings.dart';
import '../../data/leaderboard_api.dart';
import '../../data/star_leaderboard_service.dart';
import '../../domain/categories.dart';
import '../../domain/level_progression.dart';
import '../../domain/models.dart';
import '../../domain/puzzle_engine.dart';
import '../widgets/category_thumbnail.dart';
import '../widgets/clay_ui.dart';
import '../widgets/game_refresh_indicator.dart';

String _formatCampaignTime(int totalSeconds) {
  if (totalSeconds <= 0) {
    return '--:--:--';
  }
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    required this.initialCategory,
    required this.initialDifficulty,
    required this.initialMode,
    this.api,
    this.starService,
    super.key,
  });

  final WordCategory initialCategory;
  final Difficulty initialDifficulty;
  final GameMode initialMode;
  final LeaderboardApi? api;
  final StarLeaderboardService? starService;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final _api = widget.api ?? LeaderboardApi();
  late final _starService = widget.starService ?? StarLeaderboardService();
  late WordCategory _category = widget.initialCategory;
  late Difficulty _difficulty = widget.initialDifficulty;
  late LeaderboardMode _mode = LeaderboardModeX.fromGameMode(
    widget.initialMode,
  );
  List<LeaderboardEntry> _entries = [];
  StarLeaderboardSnapshot? _starSnapshot;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    final category = _category;
    final difficulty = _difficulty;
    final mode = _mode;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final StarLeaderboardSnapshot? starSnapshot;
      final List<LeaderboardEntry> entries;
      if (mode == LeaderboardMode.stars) {
        starSnapshot = await _starService.loadAndSync();
        entries = starSnapshot.entries;
      } else {
        starSnapshot = null;
        entries = await _api.fetchLeaderboard(
          mode.storageName,
          category.id,
          difficulty.storageName,
        );
      }
      if (mounted && requestId == _requestId) {
        setState(() {
          _entries = entries;
          _starSnapshot = starSnapshot;
        });
      }
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  void _setCategory(WordCategory category) {
    setState(() => _category = category);
    _load();
  }

  void _setDifficulty(Difficulty difficulty) {
    setState(() => _difficulty = difficulty);
    _load();
  }

  void _setMode(LeaderboardMode mode) {
    setState(() => _mode = mode);
    _load();
  }

  Future<void> _showCategoryPicker() async {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final selectionColor = palette.titleColor;
    final selected = await showModalBottomSheet<WordCategory>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      showDragHandle: false,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.76,
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: palette.sheetSurface.withValues(
                    alpha: palette.isDark ? 0.96 : 0.96,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  border: Border.all(color: palette.tileBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: palette.isDark ? 0.28 : 0.12,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: palette.tileBorder,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      strings.chooseCategory,
                      style: TextStyle(
                        color: palette.titleColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: wordCategories.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final category = wordCategories[index];
                          final selected = category.id == _category.id;
                          return ListTile(
                            onTap: () => Navigator.of(context).pop(category),
                            dense: true,
                            minLeadingWidth: 26,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: selected
                                    ? selectionColor.withValues(alpha: 0.62)
                                    : palette.tileBorder,
                              ),
                            ),
                            tileColor: selected
                                ? selectionColor.withValues(alpha: 0.16)
                                : palette.tileSurface,
                            leading: CategoryThumbnail(
                              category: category,
                              size: 34,
                              borderRadius: 9,
                            ),
                            title: Text(
                              strings.categoryName(category.id),
                              style: TextStyle(
                                color: palette.titleColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              strings.categoryDescription(category.id),
                              style: TextStyle(
                                color: palette.mutedColor,
                                fontSize: 12,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check_circle,
                                    color: selectionColor,
                                  )
                                : Icon(
                                    Icons.chevron_right,
                                    color: palette.mutedColor,
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
        );
      },
    );
    if (selected != null && selected.id != _category.id) {
      _setCategory(selected);
    }
  }

  Future<void> _showFilters() async {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      showDragHandle: false,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ClayBottomSheetShell(
              accentColor: palette.hintColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClayWorldTitle(strings.leaderboardFilters, fontSize: 24),
                  const SizedBox(height: 18),
                  _ModeSegmentedControl(
                    selectedMode: _mode,
                    onChanged: (mode) {
                      _setMode(mode);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_mode == LeaderboardMode.stars)
                    _StarSummaryBar(snapshot: _starSnapshot)
                  else ...[
                    _CategoryFilterButton(
                      category: _category,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            unawaited(_showCategoryPicker());
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _DifficultySegmentedControl(
                      selectedDifficulty: _difficulty,
                      onChanged: (difficulty) {
                        _setDifficulty(difficulty);
                        setSheetState(() {});
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: ClayWorldColors.deepPurple,
                        foregroundColor: ClayWorldColors.creamHighlight,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(strings.done),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Scaffold(
      body: ClaySceneBackdrop(
        assetPath: 'assets/ui/clay/scenes/leaderboard-world-v1.webp',
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
                      title: strings.leaderboard,
                      onBack: () => Navigator.of(context).pop(),
                      onAction: _showFilters,
                      actionIcon: Icons.tune_rounded,
                      actionTooltip: strings.leaderboardFilters,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(19, 4, 19, 0),
                    child: Row(
                      children: [
                        if (_mode == LeaderboardMode.stars)
                          Icon(
                            Icons.star_rounded,
                            color: palette.hintColor,
                            size: 24,
                          )
                        else
                          CategoryThumbnail(
                            category: _category,
                            size: 24,
                            borderRadius: 7,
                          ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _mode == LeaderboardMode.stars
                                ? strings.allThemes
                                : strings.categoryName(_category.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.pageForegroundColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _mode == LeaderboardMode.stars
                              ? '${_starSnapshot?.totalStars ?? '--'}/${StarLeaderboardService.maxStars}'
                              : '${strings.difficultyLabel(_difficulty)} · ${strings.leaderboardModeLabel(_mode)}',
                          style: TextStyle(
                            color: palette.pageMutedForegroundColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GameRefreshIndicator(
                      onRefresh: _load,
                      color: palette.refreshAccent,
                      icon: Icons.emoji_events,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _loading
                            ? const _LeaderboardSkeleton(
                                key: ValueKey('loading-shell'),
                              )
                            : _error != null
                            ? _ScrollableState(
                                key: const ValueKey('error-shell'),
                                child: _ErrorState(
                                  message: _error,
                                  onRetry: _load,
                                ),
                              )
                            : _entries.isEmpty
                            ? _ScrollableState(
                                child: _EmptyState(
                                  starMode: _mode == LeaderboardMode.stars,
                                ),
                              )
                            : _EntriesList(entries: _entries, mode: _mode),
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

class _CategoryFilterButton extends StatelessWidget {
  const _CategoryFilterButton({required this.category, required this.onTap});

  final WordCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return SizedBox(
      height: 40,
      child: Material(
        color: palette.tileSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        shadowColor: palette.titleColor.withValues(alpha: 0.16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.tileBorder, width: 1.2),
            ),
            child: Row(
              children: [
                CategoryThumbnail(
                  category: category,
                  size: 26,
                  borderRadius: 7,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    strings.categoryName(category.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.titleColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: palette.mutedColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSegmentedControl extends StatelessWidget {
  const _ModeSegmentedControl({
    required this.selectedMode,
    required this.onChanged,
  });

  final LeaderboardMode selectedMode;
  final ValueChanged<LeaderboardMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return _SegmentShell(
      height: 40,
      children: LeaderboardMode.values
          .map((mode) {
            final selected = mode == selectedMode;
            return Expanded(
              child: _SegmentButton(
                selected: selected,
                label: strings.leaderboardModeLabel(mode),
                icon: switch (mode) {
                  LeaderboardMode.classic => Icons.grid_view_rounded,
                  LeaderboardMode.speed => Icons.timer_rounded,
                  LeaderboardMode.stars => Icons.star_rounded,
                },
                onTap: () => onChanged(mode),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _StarSummaryBar extends StatelessWidget {
  const _StarSummaryBar({required this.snapshot});

  final StarLeaderboardSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final stars = snapshot?.totalStars;
    final completed = snapshot?.completedLevels;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.tileSurface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.tileBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: palette.titleColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: palette.hintColor, size: 18),
          const SizedBox(width: 5),
          Text(
            stars == null
                ? '--/${StarLeaderboardService.maxStars}'
                : '$stars/${StarLeaderboardService.maxStars}',
            style: TextStyle(
              color: palette.titleColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            completed == null
                ? strings.completedLevelCount(0, campaignLevels.length)
                : strings.completedLevelCount(completed, campaignLevels.length),
            style: TextStyle(
              color: palette.mutedColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultySegmentedControl extends StatelessWidget {
  const _DifficultySegmentedControl({
    required this.selectedDifficulty,
    required this.onChanged,
  });

  final Difficulty selectedDifficulty;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return _SegmentShell(
      height: 40,
      children: Difficulty.values
          .map((difficulty) {
            final selected = difficulty == selectedDifficulty;
            return Expanded(
              child: _SegmentButton(
                selected: selected,
                label: strings.difficultyLabel(difficulty),
                onTap: () => onChanged(difficulty),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _SegmentShell extends StatelessWidget {
  const _SegmentShell({required this.height, required this.children});

  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.sheetSurface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.tileBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: palette.titleColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: children),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final foreground = selected ? palette.titleColor : palette.mutedColor;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? palette.iconSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? palette.tileBorder : Colors.transparent,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: foreground, size: 14),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 13,
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

class _ScrollableState extends StatelessWidget {
  const _ScrollableState({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('scrollable-state'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        36 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [child],
    );
  }
}

class _EntriesList extends StatelessWidget {
  const _EntriesList({required this.entries, required this.mode});

  final List<LeaderboardEntry> entries;
  final LeaderboardMode mode;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('entries'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        36 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 7),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final rank = index + 1;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 260 + index * 38),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 12),
                child: child,
              ),
            );
          },
          child: _LeaderboardEntryTile(
            key: ValueKey('leaderboard-entry-$rank'),
            entry: entry,
            rank: rank,
            mode: mode,
          ),
        );
      },
    );
  }
}

class _LeaderboardEntryTile extends StatelessWidget {
  const _LeaderboardEntryTile({
    required this.entry,
    required this.rank,
    required this.mode,
    super.key,
  });

  final LeaderboardEntry entry;
  final int rank;
  final LeaderboardMode mode;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final medalColor = switch (rank) {
      1 => const Color(0xFFD99A12),
      2 => const Color(0xFF7B8A9A),
      3 => const Color(0xFFB86B3D),
      _ => palette.tileBorder,
    };
    final surface = rank <= 3
        ? Color.alphaBlend(
            medalColor.withValues(alpha: palette.isDark ? 0.12 : 0.08),
            palette.sheetSurface,
          )
        : palette.sheetSurface;
    final scoreColor = palette.isDark
        ? const Color(0xFFFFCA55)
        : const Color(0xFF9A6810);
    final timeLabel = mode == LeaderboardMode.stars
        ? _formatCampaignTime(entry.time)
        : formatSeconds(entry.time);
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: palette.isDark ? 0.93 : 0.91),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank <= 3
              ? medalColor.withValues(alpha: 0.46)
              : palette.tileBorder,
          width: rank <= 3 ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.14 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _RankBadge(rank: rank),
          const SizedBox(width: 8),
          _PlayerAvatar(entry: entry, accentColor: medalColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.titleColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${entry.date.month}/${entry.date.day}/${entry.date.year}',
                      style: TextStyle(
                        color: palette.mutedColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: palette.mutedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Icon(
                      Icons.schedule_rounded,
                      color: palette.mutedColor,
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        timeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.mutedColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mode == LeaderboardMode.stars
                    ? Icons.star_rounded
                    : Icons.monetization_on_rounded,
                color: scoreColor,
                size: 16,
              ),
              const SizedBox(width: 3),
              Text(
                mode == LeaderboardMode.stars
                    ? '${entry.score}/${StarLeaderboardService.maxStars}'
                    : '${entry.score}',
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.entry, required this.accentColor});

  final LeaderboardEntry entry;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final name = entry.name.trim();
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.iconSurface,
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.46),
          width: 1.4,
        ),
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          color: palette.titleColor,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    if (rank <= 3) {
      final medalColor = switch (rank) {
        1 => const Color(0xFFD99A12),
        2 => const Color(0xFF7B8A9A),
        _ => const Color(0xFFB86B3D),
      };
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 460 + rank * 80),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.rotate(
            angle: (1 - value.clamp(0.0, 1.0)) * -0.22,
            child: Transform.scale(
              scale: 0.54 + value.clamp(0.0, 1.0) * 0.46,
              child: child,
            ),
          );
        },
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(
              color: medalColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              color: medalColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 15,
      backgroundColor: palette.iconSurface,
      child: Text(
        '$rank',
        style: TextStyle(
          color: palette.titleColor,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LeaderboardSkeleton extends StatefulWidget {
  const _LeaderboardSkeleton({super.key});

  @override
  State<_LeaderboardSkeleton> createState() => _LeaderboardSkeletonState();
}

class _LeaderboardSkeletonState extends State<_LeaderboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ListView.separated(
          key: const ValueKey('loading'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            36 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 260 + index * 55),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 12),
                    child: child,
                  ),
                );
              },
              child: _SkeletonTile(
                shimmer: (_controller.value + index * 0.13) % 1,
                prominent: index < 3,
              ),
            );
          },
        );
      },
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.shimmer, required this.prominent});

  final double shimmer;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: prominent
            ? palette.titleColor.withValues(alpha: palette.isDark ? 0.14 : 0.09)
            : palette.sheetSurface.withValues(
                alpha: palette.isDark ? 0.82 : 0.78,
              ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: prominent
              ? palette.titleColor.withValues(alpha: 0.28)
              : palette.tileBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.14 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _SkeletonBlock(
            width: 30,
            height: 30,
            radius: 99,
            shimmer: shimmer,
            color: palette.titleColor,
          ),
          const SizedBox(width: 8),
          _SkeletonBlock(
            width: 38,
            height: 38,
            radius: 99,
            shimmer: (shimmer + 0.08) % 1,
            color: palette.titleColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SkeletonBlock(
                  width: 116,
                  height: 13,
                  radius: 99,
                  shimmer: shimmer,
                  color: palette.titleColor,
                ),
                const SizedBox(height: 8),
                _SkeletonBlock(
                  width: 76,
                  height: 9,
                  radius: 99,
                  shimmer: (shimmer + 0.18) % 1,
                  color: palette.bodyColor,
                ),
              ],
            ),
          ),
          _SkeletonBlock(
            width: 92,
            height: 14,
            radius: 99,
            shimmer: (shimmer + 0.3) % 1,
            color: palette.titleColor,
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.shimmer,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final double shimmer;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final highlight = (1 - (shimmer - 0.5).abs() * 2).clamp(0.0, 1.0);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            palette.iconSurface,
            color.withValues(alpha: 0.08 + highlight * 0.16),
            palette.iconSurface,
          ],
          stops: [
            (shimmer - 0.32).clamp(0.0, 1.0),
            shimmer.clamp(0.0, 1.0),
            (shimmer + 0.32).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF87171).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF87171).withValues(alpha: 0.36),
              ),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFF87171),
              size: 23,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.failedLoadLeaderboard,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.pageForegroundColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              strings.localizedError(message),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.pageMutedForegroundColor,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.pageForegroundColor,
              backgroundColor: palette.pageForegroundColor.withValues(
                alpha: palette.isDark ? 0.1 : 0.08,
              ),
              side: BorderSide(
                color: palette.pageForegroundColor.withValues(alpha: 0.2),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 17),
            label: Text(strings.tryAgain),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.starMode});

  final bool starMode;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Padding(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD99A12).withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD99A12).withValues(alpha: 0.42),
              ),
            ),
            child: Icon(
              starMode ? Icons.star_rounded : Icons.workspace_premium,
              color: Color(0xFFD99A12),
              size: 25,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            strings.noScoresYet,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.pageForegroundColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            starMode ? strings.beFirstStarRank : strings.beFirstScore,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.pageMutedForegroundColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
