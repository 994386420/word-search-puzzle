import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class KidAliasStore {
  KidAliasStore({SharedPreferences? preferences, Random? random})
    : _preferences = preferences,
      _random = random ?? Random.secure();

  static const aliasKey = 'kid_safe_alias_v1';

  final SharedPreferences? _preferences;
  final Random _random;

  Future<String> getOrCreate() async {
    final prefs = await _getPreferences();
    final existing = prefs.getString(aliasKey);
    if (existing != null && isSafeAlias(existing)) {
      return existing;
    }
    final alias = generate(_random);
    await prefs.setString(aliasKey, alias);
    return alias;
  }

  static String generate(Random random) {
    final adjective = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    final number = 10 + random.nextInt(90);
    return '$adjective$noun$number';
  }

  static bool isSafeAlias(String alias) {
    return alias.length >= 6 &&
        alias.length <= 20 &&
        RegExp(r'^[A-Za-z]+[0-9]{2}$').hasMatch(alias);
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  static const _adjectives = [
    'Sunny',
    'Happy',
    'Brave',
    'Clever',
    'Bright',
    'Jolly',
    'Kind',
    'Swift',
  ];

  static const _nouns = [
    'Star',
    'Rocket',
    'Panda',
    'Comet',
    'Tiger',
    'Dolphin',
    'Finder',
    'Wizard',
  ];
}
