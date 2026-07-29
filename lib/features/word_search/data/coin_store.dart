import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CoinSpendResult {
  const CoinSpendResult({required this.spent, required this.balance});

  final bool spent;
  final int balance;
}

class CoinRewardResult {
  const CoinRewardResult({
    required this.earned,
    required this.balance,
    required this.alreadyClaimed,
  });

  final int earned;
  final int balance;
  final bool alreadyClaimed;
}

class CoinStore {
  const CoinStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const initialBalance = 200;
  static const rewardedVideoCoins = 60;
  static const dailyChallengeReward = 80;
  static const regularPuzzleReward = 10;
  static const _balanceKey = 'coin_wallet_balance_v1';
  static const _claimedLevelRewardsKey = 'coin_claimed_level_rewards_v1';

  final SharedPreferences? _preferences;

  static int hintCost(int hintsUsed, {int prepaidHintsLeft = 0}) {
    if (prepaidHintsLeft > 0) {
      return 0;
    }
    return switch (hintsUsed) {
      <= 0 => 0,
      1 => 10,
      _ => 20,
    };
  }

  static int levelReward(int stars) => switch (stars.clamp(1, 3)) {
    1 => 30,
    2 => 45,
    _ => 60,
  };

  Future<int> getBalance() async {
    final prefs = await _getPreferences();
    return prefs.getInt(_balanceKey) ?? initialBalance;
  }

  Future<CoinSpendResult> spend(int amount) async {
    final prefs = await _getPreferences();
    final balance = prefs.getInt(_balanceKey) ?? initialBalance;
    final safeAmount = amount < 0 ? 0 : amount;
    if (balance < safeAmount) {
      return CoinSpendResult(spent: false, balance: balance);
    }
    final updated = balance - safeAmount;
    await prefs.setInt(_balanceKey, updated);
    return CoinSpendResult(spent: true, balance: updated);
  }

  Future<CoinRewardResult> earn(int amount) async {
    final prefs = await _getPreferences();
    final balance = prefs.getInt(_balanceKey) ?? initialBalance;
    final safeAmount = amount < 0 ? 0 : amount;
    final updated = balance + safeAmount;
    await prefs.setInt(_balanceKey, updated);
    return CoinRewardResult(
      earned: safeAmount,
      balance: updated,
      alreadyClaimed: false,
    );
  }

  Future<CoinRewardResult> claimLevelReward({
    required String levelId,
    required int stars,
  }) async {
    final prefs = await _getPreferences();
    final claimed = _decodeClaimed(prefs.getString(_claimedLevelRewardsKey));
    final balance = prefs.getInt(_balanceKey) ?? initialBalance;
    if (claimed.contains(levelId)) {
      return CoinRewardResult(
        earned: 0,
        balance: balance,
        alreadyClaimed: true,
      );
    }
    final reward = levelReward(stars);
    final updated = balance + reward;
    claimed.add(levelId);
    await Future.wait([
      prefs.setInt(_balanceKey, updated),
      prefs.setString(
        _claimedLevelRewardsKey,
        jsonEncode(claimed.toList(growable: false)..sort()),
      ),
    ]);
    return CoinRewardResult(
      earned: reward,
      balance: updated,
      alreadyClaimed: false,
    );
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  Set<String> _decodeClaimed(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => item.toString())
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }
}
