import 'package:flutter/material.dart';

import '../../domain/kid_word_catalog.dart';

class WordIllustration extends StatelessWidget {
  const WordIllustration({
    required this.word,
    required this.width,
    required this.height,
    this.categoryId,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    super.key,
  });

  final String word;
  final String? categoryId;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final assetPath = kidWordVisualAssetFor(word, categoryId: categoryId);
    final fallback = _IllustrationFallback(
      word: word,
      width: width,
      height: height,
    );
    final image = assetPath == null
        ? fallback
        : Image.asset(
            assetPath,
            width: width,
            height: height,
            fit: fit,
            semanticLabel: semanticLabel ?? word,
            errorBuilder: (_, _, _) => fallback,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: width, height: height, child: image),
    );
  }
}

class _IllustrationFallback extends StatelessWidget {
  const _IllustrationFallback({
    required this.word,
    required this.width,
    required this.height,
  });

  final String word;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: height.clamp(18, 42) * 0.58,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
