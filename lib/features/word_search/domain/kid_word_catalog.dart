import 'dart:math';

import 'models.dart';

enum KidWordLevel { starter, explorer, master }

class KidWordMetadata {
  const KidWordMetadata({required this.word, required this.level});

  final String word;
  final KidWordLevel level;

  String? get visualAsset => kidWordVisualAssetFor(word);
}

String? kidWordVisualAssetFor(String word, {String? categoryId}) {
  final normalized = word.trim().toUpperCase();
  if (categoryId != null) {
    final categoryAsset =
        kidWordCategoryVisualAssets['${categoryId.trim().toLowerCase()}:$normalized'];
    if (categoryAsset != null) {
      return categoryAsset;
    }
  }
  return kidWordVisualAssets[normalized];
}

const kidWordCategoryVisualAssets = <String, String>{
  'tech:CLOUD': 'assets/words/tech/cloud.webp',
};

const kidWordVisualAssets = <String, String>{
  'LION': 'assets/words/animals/lion.webp',
  'TIGER': 'assets/words/animals/tiger.webp',
  'PANDA': 'assets/words/animals/panda.webp',
  'WOLF': 'assets/words/animals/wolf.webp',
  'KOALA': 'assets/words/animals/koala.webp',
  'MONKEY': 'assets/words/animals/monkey.webp',
  'ZEBRA': 'assets/words/animals/zebra.webp',
  'HIPPO': 'assets/words/animals/hippo.webp',
  'PARROT': 'assets/words/animals/parrot.webp',
  'EAGLE': 'assets/words/animals/eagle.webp',
  'PENGUIN': 'assets/words/animals/penguin.webp',
  'DOLPHIN': 'assets/words/animals/dolphin.webp',
  'GIRAFFE': 'assets/words/animals/giraffe.webp',
  'ELEPHANT': 'assets/words/animals/elephant.webp',
  'CHEETAH': 'assets/words/animals/cheetah.webp',
  'PYTHON': 'assets/words/animals/python.webp',
  'GORILLA': 'assets/words/animals/gorilla.webp',
  'LEOPARD': 'assets/words/animals/leopard.webp',
  'JAGUAR': 'assets/words/animals/jaguar.webp',
  'RHINO': 'assets/words/animals/rhino.webp',
  'FLAMINGO': 'assets/words/animals/flamingo.webp',
  'KANGAROO': 'assets/words/animals/kangaroo.webp',
  'SHARK': 'assets/words/animals/shark.webp',
  'PEACOCK': 'assets/words/animals/peacock.webp',
  'FALCON': 'assets/words/animals/falcon.webp',
  'PIZZA': 'assets/words/food/pizza.webp',
  'BURGER': 'assets/words/food/burger.webp',
  'MANGO': 'assets/words/food/mango.webp',
  'PASTA': 'assets/words/food/pasta.webp',
  'TACOS': 'assets/words/food/tacos.webp',
  'WAFFLE': 'assets/words/food/waffle.webp',
  'SUSHI': 'assets/words/food/sushi.webp',
  'RAMEN': 'assets/words/food/ramen.webp',
  'STEAK': 'assets/words/food/steak.webp',
  'SALMON': 'assets/words/food/salmon.webp',
  'BROWNIE': 'assets/words/food/brownie.webp',
  'CURRY': 'assets/words/food/curry.webp',
  'PRETZEL': 'assets/words/food/pretzel.webp',
  'DUMPLING': 'assets/words/food/dumpling.webp',
  'CROISSANT': 'assets/words/food/croissant.webp',
  'LASAGNA': 'assets/words/food/lasagna.webp',
  'BURRITO': 'assets/words/food/burrito.webp',
  'RISOTTO': 'assets/words/food/risotto.webp',
  'TEMPURA': 'assets/words/food/tempura.webp',
  'PAELLA': 'assets/words/food/paella.webp',
  'TIRAMISU': 'assets/words/food/tiramisu.webp',
  'FALAFEL': 'assets/words/food/falafel.webp',
  'GNOCCHI': 'assets/words/food/gnocchi.webp',
  'FONDUE': 'assets/words/food/fondue.webp',
  'SASHIMI': 'assets/words/food/sashimi.webp',
  'RIVER': 'assets/words/nature/river.webp',
  'OCEAN': 'assets/words/nature/ocean.webp',
  'CLOUD': 'assets/words/nature/cloud.webp',
  'FOREST': 'assets/words/nature/forest.webp',
  'DUNE': 'assets/words/nature/dune.webp',
  'RAINBOW': 'assets/words/nature/rainbow.webp',
  'THUNDER': 'assets/words/nature/thunder.webp',
  'CANYON': 'assets/words/nature/canyon.webp',
  'MEADOW': 'assets/words/nature/meadow.webp',
  'RAPIDS': 'assets/words/nature/rapids.webp',
  'VOLCANO': 'assets/words/nature/volcano.webp',
  'GLACIER': 'assets/words/nature/glacier.webp',
  'MOUNTAIN': 'assets/words/nature/mountain.webp',
  'SAVANNA': 'assets/words/nature/savanna.webp',
  'WATERFALL': 'assets/words/nature/waterfall.webp',
  'TUNDRA': 'assets/words/nature/tundra.webp',
  'DELTA': 'assets/words/nature/delta.webp',
  'WETLAND': 'assets/words/nature/wetland.webp',
  'PRAIRIE': 'assets/words/nature/prairie.webp',
  'PLATEAU': 'assets/words/nature/plateau.webp',
  'LAGOON': 'assets/words/nature/lagoon.webp',
  'GEYSER': 'assets/words/nature/geyser.webp',
  'FJORD': 'assets/words/nature/fjord.webp',
  'ESTUARY': 'assets/words/nature/estuary.webp',
  'MANGROVE': 'assets/words/nature/mangrove.webp',
  'SOCCER': 'assets/words/sports/soccer.webp',
  'TENNIS': 'assets/words/sports/tennis.webp',
  'GOLF': 'assets/words/sports/golf.webp',
  'JUDO': 'assets/words/sports/judo.webp',
  'SKIING': 'assets/words/sports/skiing.webp',
  'BOXING': 'assets/words/sports/boxing.webp',
  'HOCKEY': 'assets/words/sports/hockey.webp',
  'CYCLING': 'assets/words/sports/cycling.webp',
  'DIVING': 'assets/words/sports/diving.webp',
  'KARATE': 'assets/words/sports/karate.webp',
  'SURFING': 'assets/words/sports/surfing.webp',
  'RUGBY': 'assets/words/sports/rugby.webp',
  'ARCHERY': 'assets/words/sports/archery.webp',
  'BASEBALL': 'assets/words/sports/baseball.webp',
  'SWIMMING': 'assets/words/sports/swimming.webp',
  'FENCING': 'assets/words/sports/fencing.webp',
  'CRICKET': 'assets/words/sports/cricket.webp',
  'MARATHON': 'assets/words/sports/marathon.webp',
  'VOLLEYBALL': 'assets/words/sports/volleyball.webp',
  'BADMINTON': 'assets/words/sports/badminton.webp',
  'HANDBALL': 'assets/words/sports/handball.webp',
  'ROWING': 'assets/words/sports/rowing.webp',
  'WRESTLING': 'assets/words/sports/wrestling.webp',
  'POLO': 'assets/words/sports/polo.webp',
  'SQUASH': 'assets/words/sports/squash.webp',
  'MOON': 'assets/words/space/moon.webp',
  'MARS': 'assets/words/space/mars.webp',
  'COMET': 'assets/words/space/comet.webp',
  'VENUS': 'assets/words/space/venus.webp',
  'PLANET': 'assets/words/space/planet.webp',
  'ROCKET': 'assets/words/space/rocket.webp',
  'SATURN': 'assets/words/space/saturn.webp',
  'METEOR': 'assets/words/space/meteor.webp',
  'ORBIT': 'assets/words/space/orbit.webp',
  'ECLIPSE': 'assets/words/space/eclipse.webp',
  'AURORA': 'assets/words/space/aurora.webp',
  'JUPITER': 'assets/words/space/jupiter.webp',
  'NEPTUNE': 'assets/words/space/neptune.webp',
  'TELESCOPE': 'assets/words/space/telescope.webp',
  'ASTRONAUT': 'assets/words/space/astronaut.webp',
  'GALAXY': 'assets/words/space/galaxy.webp',
  'NEBULA': 'assets/words/space/nebula.webp',
  'COSMOS': 'assets/words/space/cosmos.webp',
  'PULSAR': 'assets/words/space/pulsar.webp',
  'QUASAR': 'assets/words/space/quasar.webp',
  'ASTEROID': 'assets/words/space/asteroid.webp',
  'URANUS': 'assets/words/space/uranus.webp',
  'SATELLITE': 'assets/words/space/satellite.webp',
  'GRAVITY': 'assets/words/space/gravity.webp',
  'SUPERNOVA': 'assets/words/space/supernova.webp',
  'PIXEL': 'assets/words/tech/pixel.webp',
  'BINARY': 'assets/words/tech/binary.webp',
  'ROUTER': 'assets/words/tech/router.webp',
  'BROWSER': 'assets/words/tech/browser.webp',
  'SERVER': 'assets/words/tech/server.webp',
  'NETWORK': 'assets/words/tech/network.webp',
  'CACHE': 'assets/words/tech/cache.webp',
  'TERMINAL': 'assets/words/tech/terminal.webp',
  'FUNCTION': 'assets/words/tech/function.webp',
  'VARIABLE': 'assets/words/tech/variable.webp',
  'DATABASE': 'assets/words/tech/database.webp',
  'SYNTAX': 'assets/words/tech/syntax.webp',
  'ALGORITHM': 'assets/words/tech/algorithm.webp',
  'COMPILER': 'assets/words/tech/compiler.webp',
  'KERNEL': 'assets/words/tech/kernel.webp',
  'POINTER': 'assets/words/tech/pointer.webp',
  'PROTOCOL': 'assets/words/tech/protocol.webp',
  'FIREWALL': 'assets/words/tech/firewall.webp',
  'BACKEND': 'assets/words/tech/backend.webp',
  'FRONTEND': 'assets/words/tech/frontend.webp',
  'DEPLOY': 'assets/words/tech/deploy.webp',
  'PIPELINE': 'assets/words/tech/pipeline.webp',
  'CLUSTER': 'assets/words/tech/cluster.webp',
  'RUNTIME': 'assets/words/tech/runtime.webp',
};

KidWordMetadata kidWordMetadataFor(String word) {
  final normalized = word.trim().toUpperCase();
  return kidWordCatalog[normalized] ??
      KidWordMetadata(
        word: normalized,
        level: normalized.length <= 6
            ? KidWordLevel.starter
            : normalized.length <= 8
            ? KidWordLevel.explorer
            : KidWordLevel.master,
      );
}

List<String> kidWordsForDifficulty(List<String> words, Difficulty difficulty) {
  final maxLevel = switch (difficulty) {
    Difficulty.easy => KidWordLevel.starter,
    Difficulty.medium => KidWordLevel.explorer,
    Difficulty.hard => KidWordLevel.master,
  };
  final filtered = words
      .where((word) => kidWordMetadataFor(word).level.index <= maxLevel.index)
      .toList(growable: false);
  return filtered.length >= difficulty.wordCount ? filtered : words;
}

List<String> selectKidWordsForRound(
  List<String> words,
  Difficulty difficulty, {
  required PuzzleConfig config,
  required Random random,
  ClueMode clueMode = ClueMode.words,
  String? categoryId,
  Set<String> recentWords = const {},
  Map<String, int> usageCounts = const {},
}) {
  final candidates = kidWordCandidatesForRound(
    words,
    difficulty,
    config: config,
    clueMode: clueMode,
    categoryId: categoryId,
  );
  if (candidates.isEmpty) {
    return const [];
  }
  final targetLevel = switch (difficulty) {
    Difficulty.easy => KidWordLevel.starter,
    Difficulty.medium => KidWordLevel.explorer,
    Difficulty.hard => KidWordLevel.master,
  };
  final ranked =
      candidates
          .map(
            (word) => (
              word: word,
              score:
                  (recentWords.contains(word) ? 100000 : 0) +
                  (usageCounts[word] ?? 0) * 1000 +
                  (targetLevel.index - kidWordMetadataFor(word).level.index)
                          .abs() *
                      100 +
                  random.nextInt(1000),
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => a.score.compareTo(b.score));
  return ranked
      .take(min(config.wordCount, ranked.length))
      .map((entry) => entry.word)
      .toList(growable: false);
}

List<String> kidWordCandidatesForRound(
  List<String> words,
  Difficulty difficulty, {
  required PuzzleConfig config,
  ClueMode clueMode = ClueMode.words,
  String? categoryId,
}) {
  bool isEligible(String word) =>
      word.length <= config.gridSize &&
      (clueMode != ClueMode.pictures ||
          kidWordVisualAssetFor(word, categoryId: categoryId) != null);

  final filtered = kidWordsForDifficulty(
    words,
    difficulty,
  ).where(isEligible).toList(growable: false);
  if (filtered.length >= config.wordCount) {
    return filtered;
  }
  return words.where(isEligible).toList(growable: false);
}

const kidWordCatalog = <String, KidWordMetadata>{
  'LION': KidWordMetadata(word: 'LION', level: KidWordLevel.starter),
  'TIGER': KidWordMetadata(word: 'TIGER', level: KidWordLevel.starter),
  'PANDA': KidWordMetadata(word: 'PANDA', level: KidWordLevel.starter),
  'WOLF': KidWordMetadata(word: 'WOLF', level: KidWordLevel.starter),
  'KOALA': KidWordMetadata(word: 'KOALA', level: KidWordLevel.starter),
  'MONKEY': KidWordMetadata(word: 'MONKEY', level: KidWordLevel.starter),
  'ZEBRA': KidWordMetadata(word: 'ZEBRA', level: KidWordLevel.explorer),
  'HIPPO': KidWordMetadata(word: 'HIPPO', level: KidWordLevel.explorer),
  'PARROT': KidWordMetadata(word: 'PARROT', level: KidWordLevel.explorer),
  'EAGLE': KidWordMetadata(word: 'EAGLE', level: KidWordLevel.explorer),
  'PENGUIN': KidWordMetadata(word: 'PENGUIN', level: KidWordLevel.explorer),
  'DOLPHIN': KidWordMetadata(word: 'DOLPHIN', level: KidWordLevel.master),
  'GIRAFFE': KidWordMetadata(word: 'GIRAFFE', level: KidWordLevel.master),
  'ELEPHANT': KidWordMetadata(word: 'ELEPHANT', level: KidWordLevel.master),
  'CHEETAH': KidWordMetadata(word: 'CHEETAH', level: KidWordLevel.master),
  'PIZZA': KidWordMetadata(word: 'PIZZA', level: KidWordLevel.starter),
  'BURGER': KidWordMetadata(word: 'BURGER', level: KidWordLevel.starter),
  'MANGO': KidWordMetadata(word: 'MANGO', level: KidWordLevel.starter),
  'PASTA': KidWordMetadata(word: 'PASTA', level: KidWordLevel.starter),
  'TACOS': KidWordMetadata(word: 'TACOS', level: KidWordLevel.starter),
  'WAFFLE': KidWordMetadata(word: 'WAFFLE', level: KidWordLevel.starter),
  'SUSHI': KidWordMetadata(word: 'SUSHI', level: KidWordLevel.explorer),
  'RAMEN': KidWordMetadata(word: 'RAMEN', level: KidWordLevel.explorer),
  'STEAK': KidWordMetadata(word: 'STEAK', level: KidWordLevel.explorer),
  'SALMON': KidWordMetadata(word: 'SALMON', level: KidWordLevel.explorer),
  'BROWNIE': KidWordMetadata(word: 'BROWNIE', level: KidWordLevel.explorer),
  'CURRY': KidWordMetadata(word: 'CURRY', level: KidWordLevel.master),
  'PRETZEL': KidWordMetadata(word: 'PRETZEL', level: KidWordLevel.master),
  'DUMPLING': KidWordMetadata(word: 'DUMPLING', level: KidWordLevel.master),
  'CROISSANT': KidWordMetadata(word: 'CROISSANT', level: KidWordLevel.master),
  'RIVER': KidWordMetadata(word: 'RIVER', level: KidWordLevel.starter),
  'OCEAN': KidWordMetadata(word: 'OCEAN', level: KidWordLevel.starter),
  'CLOUD': KidWordMetadata(word: 'CLOUD', level: KidWordLevel.starter),
  'FOREST': KidWordMetadata(word: 'FOREST', level: KidWordLevel.starter),
  'DUNE': KidWordMetadata(word: 'DUNE', level: KidWordLevel.starter),
  'RAINBOW': KidWordMetadata(word: 'RAINBOW', level: KidWordLevel.starter),
  'THUNDER': KidWordMetadata(word: 'THUNDER', level: KidWordLevel.explorer),
  'CANYON': KidWordMetadata(word: 'CANYON', level: KidWordLevel.explorer),
  'MEADOW': KidWordMetadata(word: 'MEADOW', level: KidWordLevel.explorer),
  'RAPIDS': KidWordMetadata(word: 'RAPIDS', level: KidWordLevel.explorer),
  'VOLCANO': KidWordMetadata(word: 'VOLCANO', level: KidWordLevel.explorer),
  'GLACIER': KidWordMetadata(word: 'GLACIER', level: KidWordLevel.master),
  'MOUNTAIN': KidWordMetadata(word: 'MOUNTAIN', level: KidWordLevel.master),
  'SAVANNA': KidWordMetadata(word: 'SAVANNA', level: KidWordLevel.master),
  'WATERFALL': KidWordMetadata(word: 'WATERFALL', level: KidWordLevel.master),
  'SOCCER': KidWordMetadata(word: 'SOCCER', level: KidWordLevel.starter),
  'TENNIS': KidWordMetadata(word: 'TENNIS', level: KidWordLevel.starter),
  'GOLF': KidWordMetadata(word: 'GOLF', level: KidWordLevel.starter),
  'JUDO': KidWordMetadata(word: 'JUDO', level: KidWordLevel.starter),
  'SKIING': KidWordMetadata(word: 'SKIING', level: KidWordLevel.starter),
  'BOXING': KidWordMetadata(word: 'BOXING', level: KidWordLevel.starter),
  'HOCKEY': KidWordMetadata(word: 'HOCKEY', level: KidWordLevel.explorer),
  'CYCLING': KidWordMetadata(word: 'CYCLING', level: KidWordLevel.explorer),
  'DIVING': KidWordMetadata(word: 'DIVING', level: KidWordLevel.explorer),
  'KARATE': KidWordMetadata(word: 'KARATE', level: KidWordLevel.explorer),
  'SURFING': KidWordMetadata(word: 'SURFING', level: KidWordLevel.explorer),
  'RUGBY': KidWordMetadata(word: 'RUGBY', level: KidWordLevel.master),
  'ARCHERY': KidWordMetadata(word: 'ARCHERY', level: KidWordLevel.master),
  'BASEBALL': KidWordMetadata(word: 'BASEBALL', level: KidWordLevel.master),
  'SWIMMING': KidWordMetadata(word: 'SWIMMING', level: KidWordLevel.master),
  'MOON': KidWordMetadata(word: 'MOON', level: KidWordLevel.starter),
  'MARS': KidWordMetadata(word: 'MARS', level: KidWordLevel.starter),
  'COMET': KidWordMetadata(word: 'COMET', level: KidWordLevel.starter),
  'VENUS': KidWordMetadata(word: 'VENUS', level: KidWordLevel.starter),
  'PLANET': KidWordMetadata(word: 'PLANET', level: KidWordLevel.starter),
  'ROCKET': KidWordMetadata(word: 'ROCKET', level: KidWordLevel.starter),
  'SATURN': KidWordMetadata(word: 'SATURN', level: KidWordLevel.explorer),
  'METEOR': KidWordMetadata(word: 'METEOR', level: KidWordLevel.explorer),
  'ORBIT': KidWordMetadata(word: 'ORBIT', level: KidWordLevel.explorer),
  'ECLIPSE': KidWordMetadata(word: 'ECLIPSE', level: KidWordLevel.explorer),
  'AURORA': KidWordMetadata(word: 'AURORA', level: KidWordLevel.explorer),
  'JUPITER': KidWordMetadata(word: 'JUPITER', level: KidWordLevel.master),
  'NEPTUNE': KidWordMetadata(word: 'NEPTUNE', level: KidWordLevel.master),
  'TELESCOPE': KidWordMetadata(word: 'TELESCOPE', level: KidWordLevel.master),
  'ASTRONAUT': KidWordMetadata(word: 'ASTRONAUT', level: KidWordLevel.master),
  'PIXEL': KidWordMetadata(word: 'PIXEL', level: KidWordLevel.starter),
  'BINARY': KidWordMetadata(word: 'BINARY', level: KidWordLevel.starter),
  'ROUTER': KidWordMetadata(word: 'ROUTER', level: KidWordLevel.starter),
  'BROWSER': KidWordMetadata(word: 'BROWSER', level: KidWordLevel.starter),
  'SERVER': KidWordMetadata(word: 'SERVER', level: KidWordLevel.starter),
  'NETWORK': KidWordMetadata(word: 'NETWORK', level: KidWordLevel.starter),
  'CACHE': KidWordMetadata(word: 'CACHE', level: KidWordLevel.explorer),
  'TERMINAL': KidWordMetadata(word: 'TERMINAL', level: KidWordLevel.explorer),
  'FUNCTION': KidWordMetadata(word: 'FUNCTION', level: KidWordLevel.explorer),
  'VARIABLE': KidWordMetadata(word: 'VARIABLE', level: KidWordLevel.explorer),
  'DATABASE': KidWordMetadata(word: 'DATABASE', level: KidWordLevel.explorer),
  'SYNTAX': KidWordMetadata(word: 'SYNTAX', level: KidWordLevel.master),
  'ALGORITHM': KidWordMetadata(word: 'ALGORITHM', level: KidWordLevel.master),
  'COMPILER': KidWordMetadata(word: 'COMPILER', level: KidWordLevel.master),
};
