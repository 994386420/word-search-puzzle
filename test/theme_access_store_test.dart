import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/theme_access_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('rewarded theme access lasts for the current day', () async {
    const store = ThemeAccessStore();
    final today = DateTime(2026, 7, 14);

    await store.unlockForToday('space', now: today);

    expect(await store.dailyUnlockedThemeIds(now: today), contains('space'));
    expect(
      await store.dailyUnlockedThemeIds(
        now: today.add(const Duration(days: 1)),
      ),
      isEmpty,
    );
  });

  test('family access persists independently', () async {
    const store = ThemeAccessStore();

    await store.setFamilyAccess(true);

    expect(await store.hasFamilyAccess(), isTrue);
  });
}
