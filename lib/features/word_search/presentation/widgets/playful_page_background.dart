import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/skin_visuals.dart';

class PlayfulPageBackground extends StatelessWidget {
  const PlayfulPageBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final skin = SkinVisuals.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            SkinVisuals.homeBackgroundAsset(skin),
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
          ),
        ),
        if (palette.isDark)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.pageGradientColors.first.withValues(alpha: 0.78),
                    palette.pageGradientColors[1].withValues(alpha: 0.64),
                    palette.pageGradientColors.last.withValues(alpha: 0.56),
                  ],
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
