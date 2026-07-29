import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/skin_visuals.dart';
import '../../data/appearance_preference_store.dart';

class ClaySceneBackdrop extends StatelessWidget {
  const ClaySceneBackdrop({
    required this.assetPath,
    required this.child,
    super.key,
    this.alignment = Alignment.bottomCenter,
    this.foregroundGradient = true,
  });

  final String assetPath;
  final Widget child;
  final Alignment alignment;
  final bool foregroundGradient;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final skin = SkinVisuals.of(context);
    final resolvedAssetPath = SkinVisuals.sceneAsset(assetPath, skin);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Image.asset(
            resolvedAssetPath,
            key: ValueKey('clay-scene-asset-${skin.name}'),
            fit: BoxFit.cover,
            alignment: alignment,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) => DecoratedBox(
              decoration: BoxDecoration(gradient: palette.pageGradient),
            ),
          ),
        ),
        if (foregroundGradient)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.isDark
                      ? palette.pageGradientColors.first.withValues(alpha: 0.7)
                      : const Color(0x22000000),
                  Colors.transparent,
                  palette.isDark
                      ? palette.pageGradientColors.last.withValues(alpha: 0.34)
                      : const Color(0x16000000),
                ],
                stops: const [0, 0.3, 1],
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class ClayWorldTitle extends StatelessWidget {
  const ClayWorldTitle(
    this.text, {
    super.key,
    this.fontSize = 32,
    this.maxLines = 2,
  });

  final String text;
  final double fontSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final skin = SkinVisuals.of(context);
    final title = text.toUpperCase();
    final fillColor = palette.isDark || skin == AppSkin.starry
        ? palette.pageForegroundColor
        : ClayWorldColors.deepPurple;
    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: 0.94,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    );

    Text titleLayer(TextStyle style) => Text(
      title,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style,
    );

    return Semantics(
      header: true,
      label: text,
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(0, fontSize * 0.15),
              child: titleLayer(
                baseStyle.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = fontSize * 0.16
                    ..strokeJoin = StrokeJoin.round
                    ..color = ClayWorldColors.deepPurpleShadow,
                ),
              ),
            ),
            titleLayer(
              baseStyle.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = fontSize * 0.09
                  ..strokeJoin = StrokeJoin.round
                  ..color = palette.isDark
                      ? ClayWorldColors.deepPurpleShadow
                      : ClayWorldColors.creamHighlight,
              ),
            ),
            titleLayer(
              baseStyle.copyWith(
                color: fillColor,
                shadows: [
                  Shadow(
                    color: Colors.white.withValues(
                      alpha: palette.isDark ? 0.35 : 0.72,
                    ),
                    blurRadius: 1,
                    offset: const Offset(0, -1.5),
                  ),
                  Shadow(
                    color: ClayWorldColors.deepPurpleShadow.withValues(
                      alpha: 0.3,
                    ),
                    blurRadius: 2,
                    offset: const Offset(0, 2),
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

class ClayPageHeader extends StatelessWidget {
  const ClayPageHeader({
    required this.title,
    required this.onBack,
    super.key,
    this.subtitle,
    this.onAction,
    this.actionIcon,
    this.actionTooltip,
    this.trailing,
    this.height = 72,
    this.titleFontSize = 31,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final String? actionTooltip;
  final Widget? trailing;
  final double height;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final localizations = MaterialLocalizations.of(context);
    final resolvedTrailing =
        trailing ??
        (onAction == null || actionIcon == null
            ? null
            : ClayHeaderButton(
                onTap: onAction!,
                tooltip: actionTooltip,
                icon: actionIcon!,
              ));
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ClayHeaderButton(
              onTap: onBack,
              tooltip: localizations.backButtonTooltip,
              icon: Icons.arrow_back_rounded,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 62),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClayWorldTitle(title, fontSize: titleFontSize, maxLines: 1),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.pageMutedForegroundColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (resolvedTrailing != null)
            Align(alignment: Alignment.centerRight, child: resolvedTrailing),
        ],
      ),
    );
  }
}

class ClayHeaderButton extends StatelessWidget {
  const ClayHeaderButton({
    required this.onTap,
    required this.icon,
    super.key,
    this.tooltip,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final button = ClayPressable(
      onTap: onTap,
      semanticLabel: tooltip,
      color: palette.headerButtonBackground,
      shadowColor: palette.headerButtonBorder,
      radius: 16,
      padding: EdgeInsets.zero,
      child: SizedBox.square(
        dimension: 44,
        child: Icon(icon, color: palette.headerButtonForeground, size: 23),
      ),
    );
    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, excludeFromSemantics: true, child: button);
  }
}

class ClaySurface extends StatelessWidget {
  const ClaySurface({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.radius = 22,
    this.accentColor,
    this.backgroundColor,
    this.constraints,
    this.clipBehavior = Clip.none,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? accentColor;
  final Color? backgroundColor;
  final BoxConstraints? constraints;
  final Clip clipBehavior;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final base = backgroundColor ?? palette.sheetSurface;
    final accent = accentColor ?? palette.classicButtonColor;
    final top = Color.alphaBlend(
      Colors.white.withValues(alpha: palette.isDark ? 0.06 : 0.58),
      base,
    );
    final bottom = Color.alphaBlend(
      accent.withValues(alpha: palette.isDark ? 0.055 : 0.035),
      base,
    );
    return Container(
      margin: margin,
      padding: padding,
      constraints: constraints,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, base, bottom],
          stops: const [0, 0.46, 1],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Color.alphaBlend(
            accent.withValues(alpha: palette.isDark ? 0.24 : 0.14),
            palette.tileBorder,
          ),
          width: 2.8,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Color.alphaBlend(
                    accent.withValues(alpha: palette.isDark ? 0.32 : 0.18),
                    palette.titleColor.withValues(
                      alpha: palette.isDark ? 0.3 : 0.2,
                    ),
                  ),
                  blurRadius: 1,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: -5,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.white.withValues(
                    alpha: palette.isDark ? 0.04 : 0.74,
                  ),
                  blurRadius: 2,
                  offset: const Offset(-1, -2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class ClayAssetObject extends StatelessWidget {
  const ClayAssetObject({
    required this.assetPath,
    super.key,
    this.semanticLabel,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final String assetPath;
  final String? semanticLabel;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      semanticLabel: semanticLabel,
    );
  }
}

class ClaySceneHeader extends StatelessWidget {
  const ClaySceneHeader({
    required this.title,
    required this.assetPath,
    required this.onBack,
    super.key,
    this.subtitle,
    this.onAction,
    this.actionIcon,
    this.actionTooltip,
    this.accentColor,
    this.height = 205,
    this.assetWidth = 190,
  });

  final String title;
  final String? subtitle;
  final String assetPath;
  final VoidCallback onBack;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final String? actionTooltip;
  final Color? accentColor;
  final double height;
  final double assetWidth;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    final accent = accentColor ?? palette.classicButtonColor;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 28,
            right: 28,
            bottom: 9,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: palette.isDark ? 0.18 : 0.14),
                borderRadius: const BorderRadius.all(
                  Radius.elliptical(180, 32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.titleColor.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -2,
            height: assetWidth,
            child: ClayAssetObject(assetPath: assetPath),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 14,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 66),
              child: Column(
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.isDark
                          ? palette.pageForegroundColor
                          : ClayWorldColors.deepPurple,
                      fontSize: 28,
                      height: 0.98,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: palette.isDark
                              ? Colors.black45
                              : ClayWorldColors.deepPurpleShadow.withValues(
                                  alpha: 0.4,
                                ),
                          blurRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                        Shadow(
                          color: Colors.white.withValues(
                            alpha: palette.isDark ? 0.08 : 0.7,
                          ),
                          blurRadius: 1,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.bodyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 11,
            child: _ClayHeaderButton(
              icon: Icons.arrow_back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
            ),
          ),
          if (onAction != null && actionIcon != null)
            Positioned(
              right: 11,
              top: 11,
              child: _ClayHeaderButton(
                icon: actionIcon!,
                tooltip: actionTooltip,
                onPressed: onAction!,
              ),
            ),
        ],
      ),
    );
  }
}

class _ClayHeaderButton extends StatelessWidget {
  const _ClayHeaderButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return ClayPressable(
      onTap: onPressed,
      semanticLabel: tooltip,
      color: palette.headerButtonBackground,
      shadowColor: palette.headerButtonBorder,
      radius: 16,
      padding: EdgeInsets.zero,
      child: SizedBox.square(
        dimension: 42,
        child: Icon(icon, size: 22, color: palette.headerButtonForeground),
      ),
    );
  }
}

class ClayPressable extends StatefulWidget {
  const ClayPressable({
    required this.child,
    required this.onTap,
    super.key,
    this.color = ClayWorldColors.teal,
    this.shadowColor = ClayWorldColors.tealShadow,
    this.radius = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color shadowColor;
  final double radius;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  State<ClayPressable> createState() => _ClayPressableState();
}

class _ClayPressableState extends State<ClayPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final pressOffset = _pressed ? 5.0 : 0.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, pressOffset, 0),
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.24),
                  widget.color,
                ),
                widget.color,
              ],
            ),
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.44),
              width: 2,
            ),
            boxShadow: _pressed
                ? const []
                : [
                    BoxShadow(
                      color: widget.shadowColor,
                      blurRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: widget.shadowColor.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 9),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 1,
                      offset: const Offset(0, -1),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class ClayIconBadge extends StatelessWidget {
  const ClayIconBadge({
    required this.icon,
    required this.color,
    super.key,
    this.size = 56,
    this.iconSize = 30,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: palette.isDark ? 0.08 : 0.76),
              palette.iconSurface,
            ),
            Color.alphaBlend(
              color.withValues(alpha: palette.isDark ? 0.2 : 0.14),
              palette.iconSurface,
            ),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: palette.isDark ? 0.5 : 0.36),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class ClayBottomSheetShell extends StatelessWidget {
  const ClayBottomSheetShell({
    required this.child,
    super.key,
    this.accentColor,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 20),
    this.maxWidth = 430,
  });

  final Widget child;
  final Color? accentColor;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ClaySurface(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            padding: padding,
            radius: 26,
            accentColor: accentColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.tileBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 15),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
