import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/language_preference_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists a supported language code', () async {
    const store = LanguagePreferenceStore();

    await store.setLocale(const Locale('zh'));
    final prefs = await SharedPreferences.getInstance();

    expect(await store.getLocale(), const Locale('zh'));
    expect(prefs.getString(LanguagePreferenceStore.preferenceKey), 'zh');
  });

  test(
    'uses system language when preference is cleared or unsupported',
    () async {
      const store = LanguagePreferenceStore();

      await store.setLocale(const Locale('fr'));
      expect(await store.getLocale(), isNull);

      await store.setLocale(const Locale('ko'));
      await store.setLocale(null);
      final prefs = await SharedPreferences.getInstance();

      expect(await store.getLocale(), isNull);
      expect(prefs.containsKey(LanguagePreferenceStore.preferenceKey), isFalse);
    },
  );
}
