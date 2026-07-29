import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models.dart';

class CategoryThumbnail extends StatelessWidget {
  const CategoryThumbnail({
    required this.category,
    this.size = 28,
    this.borderRadius = 8,
    this.showBorder = true,
    super.key,
  });

  final WordCategory category;
  final double size;
  final double borderRadius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final palette = WordSearchPalette.of(context);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.iconSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: palette.tileBorder) : null,
      ),
      child: Image.asset(
        category.assetPath,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => Icon(
          Icons.image_outlined,
          color: palette.mutedColor,
          size: size * 0.56,
        ),
      ),
    );
  }
}
