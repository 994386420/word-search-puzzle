import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/coin_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts with enough coins to learn the hint loop', () async {
    const store = CoinStore();

    expect(await store.getBalance(), CoinStore.initialBalance);
    expect(CoinStore.initialBalance, 200);
    expect(CoinStore.hintCost(0), 0);
    expect(CoinStore.hintCost(1), 10);
    expect(CoinStore.hintCost(2), 20);
    expect(CoinStore.hintCost(5, prepaidHintsLeft: 2), 0);
    expect(CoinStore.levelReward(1), 30);
    expect(CoinStore.levelReward(2), 45);
    expect(CoinStore.levelReward(3), 60);
    expect(CoinStore.dailyChallengeReward, 80);
    expect(CoinStore.regularPuzzleReward, 10);
  });

  test('spends only when the wallet can cover the cost', () async {
    const store = CoinStore();

    final first = await store.spend(30);
    final failed = await store.spend(200);

    expect(first.spent, isTrue);
    expect(first.balance, 170);
    expect(failed.spent, isFalse);
    expect(failed.balance, 170);
  });

  test('claims a level reward only once', () async {
    const store = CoinStore();

    final first = await store.claimLevelReward(
      levelId: 'level_animals_1',
      stars: 3,
    );
    final repeated = await store.claimLevelReward(
      levelId: 'level_animals_1',
      stars: 3,
    );

    expect(first.earned, 60);
    expect(first.balance, 260);
    expect(repeated.earned, 0);
    expect(repeated.balance, 260);
    expect(repeated.alreadyClaimed, isTrue);
  });

  test('rewarded video coins enter the same wallet', () async {
    const store = CoinStore();

    final result = await store.earn(CoinStore.rewardedVideoCoins);

    expect(result.balance, 260);
  });
}
