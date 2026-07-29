import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../l10n/app_strings.dart';
import '../../data/voice_guide_service.dart';
import '../../data/word_review_store.dart';
import '../../data/progress_store.dart';
import '../../domain/categories.dart';
import '../../domain/kid_word_catalog.dart';
import '../../domain/models.dart';
import '../../domain/word_learning.dart';
import '../widgets/game_refresh_indicator.dart';
import '../widgets/clay_ui.dart';
import '../widgets/speaking_word_icon.dart';
import '../widgets/theme_scene_assets.dart';
import '../widgets/word_illustration.dart';

class WordReviewScreen extends StatefulWidget {
  const WordReviewScreen({super.key, this.store = const WordReviewStore()});

  final WordReviewStore store;

  @override
  State<WordReviewScreen> createState() => _WordReviewScreenState();
}

class _WordReviewScreenState extends State<WordReviewScreen> {
  late final WordReviewStore _store;
  final _progressStore = ProgressStore();
  late Future<List<LearnedWordRecord>> _recordsFuture;
  bool _favoritesOnly = false;
  bool _closing = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    _recordsFuture = _store.getRecords();
    unawaited(_maybePlayReviewGuide());
  }

  Future<void> _refresh() async {
    final recordsFuture = _store.getRecords();
    setState(() {
      _recordsFuture = recordsFuture;
    });
    await recordsFuture;
  }

  Future<void> _toggleFavorite(LearnedWordRecord record) async {
    await _setFavorite(record, !record.isFavorite);
  }

  Future<void> _setFavorite(LearnedWordRecord record, bool isFavorite) async {
    await _store.setFavorite(
      word: record.word,
      isFavorite: isFavorite,
      categoryId: record.categoryId,
    );
    if (isFavorite) {
      unawaited(
        VoiceGuideService.instance.playCue(
          VoiceGuideCue.wordSaved,
          interrupt: false,
          minInterval: const Duration(seconds: 3),
          skipIfBusy: true,
        ),
      );
    }
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _openWordCard(LearnedWordRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WordDetailSheet(
        record: record,
        onFavoriteChanged: (value) => _setFavorite(record, value),
      ),
    );
    await VoiceGuideService.instance.stop();
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _maybePlayReviewGuide() async {
    final seen = await _progressStore.hasSeenReviewVoiceGuide();
    if (!mounted || seen) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) {
      return;
    }
    unawaited(
      VoiceGuideService.instance.playCue(
        VoiceGuideCue.reviewIntro,
        interrupt: false,
        minInterval: const Duration(seconds: 10),
        skipIfBusy: true,
      ),
    );
    await _progressStore.markReviewVoiceGuideSeen();
  }

  Future<void> _close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    await VoiceGuideService.instance.stop();
    if (!mounted) {
      return;
    }
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_close());
        }
      },
      child: Scaffold(
        body: ClaySceneBackdrop(
          assetPath: clayReviewSceneAsset,
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
                        title: strings.reviewWords,
                        onBack: _closing ? () {} : _close,
                        onAction: _refresh,
                        actionIcon: Icons.refresh_rounded,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _ReviewFilterBar(
                        favoritesOnly: _favoritesOnly,
                        onChanged: (value) {
                          setState(() => _favoritesOnly = value);
                        },
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<LearnedWordRecord>>(
                        future: _recordsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                                  ConnectionState.done &&
                              !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFFB84D),
                              ),
                            );
                          }
                          final allRecords = snapshot.data ?? [];
                          final records = _favoritesOnly
                              ? allRecords
                                    .where((record) => record.isFavorite)
                                    .toList(growable: false)
                              : allRecords;
                          return GameRefreshIndicator(
                            onRefresh: _refresh,
                            color: palette.refreshAccent,
                            icon: Icons.school_rounded,
                            child: records.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      30,
                                      16,
                                      42 + MediaQuery.paddingOf(context).bottom,
                                    ),
                                    children: [
                                      _EmptyReviewState(
                                        favoritesOnly: _favoritesOnly,
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      2,
                                      16,
                                      42 + MediaQuery.paddingOf(context).bottom,
                                    ),
                                    itemCount: records.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final record = records[index];
                                      return _ReviewWordTile(
                                        record: record,
                                        onOpen: () {
                                          unawaited(_openWordCard(record));
                                        },
                                        onFavoriteToggle: () {
                                          unawaited(_toggleFavorite(record));
                                        },
                                      );
                                    },
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
      ),
    );
  }
}

class _ReviewFilterBar extends StatelessWidget {
  const _ReviewFilterBar({
    required this.favoritesOnly,
    required this.onChanged,
  });

  final bool favoritesOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return ClaySurface(
      padding: const EdgeInsets.all(4),
      radius: 18,
      elevated: false,
      backgroundColor: palette.sheetSurface,
      child: Row(
        children: [
          Expanded(
            child: _ReviewFilterButton(
              selected: !favoritesOnly,
              label: strings.allWords,
              icon: Icons.format_list_bulleted_rounded,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ReviewFilterButton(
              selected: favoritesOnly,
              label: strings.favorites,
              icon: Icons.star_rounded,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewFilterButton extends StatelessWidget {
  const _ReviewFilterButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? palette.hintColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: palette.hintColor.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? const Color(0xFF5F3B00) : palette.mutedColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF5F3B00)
                      : palette.mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewWordTile extends StatelessWidget {
  const _ReviewWordTile({
    required this.record,
    required this.onOpen,
    required this.onFavoriteToggle,
  });

  final LearnedWordRecord record;
  final VoidCallback onOpen;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final category = _categoryFor(record.categoryId);
    final categoryColor = category?.accentColor ?? palette.hintColor;
    final learning = wordLearningEntryFor(record.word);
    final hasVisual =
        kidWordVisualAssetFor(record.word, categoryId: record.categoryId) !=
        null;
    return GestureDetector(
      key: ValueKey('review-word-tile-${record.word}'),
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: ClaySurface(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        radius: 18,
        accentColor: categoryColor,
        backgroundColor: palette.sheetSurface,
        child: Row(
          children: [
            if (hasVisual) ...[
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: categoryColor.withValues(alpha: 0.24),
                  ),
                ),
                child: WordIllustration(
                  key: ValueKey('review-word-image-${record.word}'),
                  word: record.word,
                  categoryId: record.categoryId,
                  width: 48,
                  height: 48,
                  borderRadius: 9,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.word,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.titleColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _SmallActionButton(
                        color: categoryColor,
                        onTap: () {
                          unawaited(
                            VoiceGuideService.instance.playWord(record.word),
                          );
                        },
                        child: SpeakingWordIcon(
                          word: record.word,
                          color: categoryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _SmallActionButton(
                        color: record.isFavorite
                            ? const Color(0xFFFFB84D)
                            : palette.mutedColor,
                        onTap: onFavoriteToggle,
                        child: Icon(
                          record.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_border,
                          color: record.isFavorite
                              ? const Color(0xFFFFB84D)
                              : palette.mutedColor,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          learning.meaningFor(strings.locale.languageCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.bodyColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category == null
                            ? record.categoryId
                            : strings.categoryName(category.id),
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordDetailSheet extends StatefulWidget {
  const _WordDetailSheet({
    required this.record,
    required this.onFavoriteChanged,
  });

  final LearnedWordRecord record;
  final Future<void> Function(bool value) onFavoriteChanged;

  @override
  State<_WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends State<_WordDetailSheet> {
  late bool _isFavorite = widget.record.isFavorite;
  bool _savingFavorite = false;

  Future<void> _toggleFavorite() async {
    if (_savingFavorite) {
      return;
    }
    final nextValue = !_isFavorite;
    setState(() {
      _isFavorite = nextValue;
      _savingFavorite = true;
    });
    await widget.onFavoriteChanged(nextValue);
    if (mounted) {
      setState(() => _savingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    final category = _categoryFor(widget.record.categoryId);
    final categoryColor = category?.accentColor ?? palette.hintColor;
    final learning = wordLearningEntryFor(widget.record.word);
    final hasVisual =
        kidWordVisualAssetFor(
          widget.record.word,
          categoryId: widget.record.categoryId,
        ) !=
        null;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return Container(
      key: ValueKey('word-detail-${widget.record.word}'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: palette.sheetSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: palette.tileBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    category == null
                        ? widget.record.categoryId
                        : strings.categoryName(category.id),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('word-detail-favorite-${widget.record.word}'),
                  tooltip: _isFavorite ? strings.savedWord : strings.saveWord,
                  onPressed: _savingFavorite ? null : _toggleFavorite,
                  icon: Icon(
                    _isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: _isFavorite
                        ? const Color(0xFFFFB84D)
                        : palette.mutedColor,
                  ),
                ),
              ],
            ),
            if (hasVisual) ...[
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final imageSize = (constraints.maxWidth - 24).clamp(
                    210.0,
                    300.0,
                  );
                  return Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: categoryColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: WordIllustration(
                      key: ValueKey('word-detail-image-${widget.record.word}'),
                      word: widget.record.word,
                      categoryId: widget.record.categoryId,
                      width: imageSize,
                      height: imageSize,
                      borderRadius: 15,
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    widget.record.word,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.titleColor,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  key: ValueKey('word-detail-audio-${widget.record.word}'),
                  tooltip: strings.playWordAudio(widget.record.word),
                  onPressed: () {
                    unawaited(
                      VoiceGuideService.instance.playWord(widget.record.word),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: categoryColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: SpeakingWordIcon(
                    word: widget.record.word,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              learning.meaningFor(strings.locale.languageCode),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.bodyColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaPill(
                  icon: Icons.repeat_rounded,
                  label: strings.timesFound(widget.record.timesFound),
                  color: const Color(0xFF38BDF8),
                ),
                _MetaPill(
                  icon: Icons.schedule_rounded,
                  label:
                      '${strings.lastSeen} ${_shortDate(widget.record.lastSeenAt)}',
                  color: const Color(0xFFA78BFA),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.child,
    required this.color,
    required this.onTap,
  });

  final Widget child;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 34, height: 34, child: Center(child: child)),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: palette.mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviewState extends StatelessWidget {
  const _EmptyReviewState({required this.favoritesOnly});

  final bool favoritesOnly;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final palette = WordSearchPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.sheetSurface.withValues(
          alpha: palette.isDark ? 0.82 : 0.84,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.tileBorder),
      ),
      child: Column(
        children: [
          Icon(
            favoritesOnly ? Icons.star_border : Icons.school_rounded,
            color: palette.hintColor,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            favoritesOnly
                ? strings.noFavoriteWordsYet
                : strings.noLearnedWordsYet,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.mutedColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
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

String _shortDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month/$day';
}
