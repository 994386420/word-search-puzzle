import '../../domain/models.dart';

const clayStatsSceneAsset = 'assets/ui/clay/scenes/stats-world-v1.webp';
const clayReviewSceneAsset = 'assets/ui/clay/scenes/review-world-v1.webp';

String clayThemeSceneAsset(WordCategory category) {
  return switch (category.id) {
    'animals' => 'assets/ui/clay/scenes/theme-animals-v1.webp',
    'food' => 'assets/ui/clay/scenes/theme-food-v1.webp',
    'nature' => 'assets/ui/clay/scenes/theme-nature-v1.webp',
    'sports' => 'assets/ui/clay/scenes/theme-sports-v1.webp',
    'space' => 'assets/ui/clay/scenes/theme-space-v1.webp',
    'tech' => 'assets/ui/clay/scenes/theme-tech-v1.webp',
    _ => 'assets/ui/clay/scenes/game-garden-v1.webp',
  };
}

String clayThemeLandmarkWord(WordCategory category) {
  return switch (category.id) {
    'animals' => 'LION',
    'food' => 'BURGER',
    'nature' => 'WATERFALL',
    'sports' => 'SOCCER',
    'space' => 'ROCKET',
    'tech' => 'ROUTER',
    _ => category.words.first,
  };
}
