import 'package:flutter/material.dart';

import '../features/word_search/data/voice_guide_service.dart';
import 'app_theme.dart';

class VoiceGuideBubbleOverlay extends StatelessWidget {
  const VoiceGuideBubbleOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<VoiceGuideBubble?>(
          valueListenable: VoiceGuideService.instance.bubbleListenable,
          builder: (context, bubble, _) {
            return Positioned(
              left: 18,
              right: 18,
              bottom: 86 + MediaQuery.paddingOf(context).bottom,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  reverseDuration: const Duration(milliseconds: 170),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.18),
                          end: Offset.zero,
                        ).animate(animation),
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.96,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: bubble == null
                      ? const SizedBox.shrink(key: ValueKey('empty'))
                      : _VoiceGuideBubble(
                          key: ValueKey(bubble.id),
                          bubble: bubble,
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _VoiceGuideBubble extends StatelessWidget {
  const _VoiceGuideBubble({required this.bubble, super.key});

  final VoiceGuideBubble bubble;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 372),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 15, 11),
            decoration: BoxDecoration(
              color: palette.sheetSurface.withValues(
                alpha: palette.isDark ? 0.94 : 0.9,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: palette.isDark ? 0.18 : 0.62,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.titleColor.withValues(
                    alpha: palette.isDark ? 0.22 : 0.12,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: palette.hintColor.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _VoicePulseIcon(color: palette.hintColor),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    bubble.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.titleColor,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
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

class _VoicePulseIcon extends StatefulWidget {
  const _VoicePulseIcon({required this.color});

  final Color color;

  @override
  State<_VoicePulseIcon> createState() => _VoicePulseIconState();
}

class _VoicePulseIconState extends State<_VoicePulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.16 + pulse * 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.42 + pulse * 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.14 + pulse * 0.12),
                blurRadius: 10 + pulse * 8,
              ),
            ],
          ),
          child: Icon(
            Icons.record_voice_over_rounded,
            color: palette.isDark ? const Color(0xFF5F3B00) : widget.color,
            size: 18,
          ),
        );
      },
    );
  }
}
