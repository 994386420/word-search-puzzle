import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/kid_alias_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('generates a bounded child-safe alias', () {
    final alias = KidAliasStore.generate(Random(7));

    expect(KidAliasStore.isSafeAlias(alias), isTrue);
    expect(alias.length, lessThanOrEqualTo(20));
    expect(alias, matches(RegExp(r'^[A-Za-z]+[0-9]{2}$')));
  });

  test('persists the same anonymous alias', () async {
    final store = KidAliasStore(random: Random(8));

    final first = await store.getOrCreate();
    final second = await store.getOrCreate();

    expect(second, first);
  });

  test('replaces an unsafe stored value', () async {
    SharedPreferences.setMockInitialValues({
      KidAliasStore.aliasKey: 'Real Child School Name',
    });
    final store = KidAliasStore(random: Random(9));

    final alias = await store.getOrCreate();

    expect(alias, isNot('Real Child School Name'));
    expect(KidAliasStore.isSafeAlias(alias), isTrue);
  });
}
