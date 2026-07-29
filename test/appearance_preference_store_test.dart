import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/appearance_preference_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists explicit appearance modes', () async {
    const store = AppearancePreferenceStore();

    await store.setMode(AppearanceMode.dark);
    final prefs = await SharedPreferences.getInstance();

    expect(await store.getMode(), AppearanceMode.dark);
    expect(prefs.getString(AppearancePreferenceStore.preferenceKey), 'dark');

    await store.setMode(AppearanceMode.system);
    expect(await store.getMode(), AppearanceMode.system);
    expect(prefs.getString(AppearancePreferenceStore.preferenceKey), 'system');
  });

  test('uses light appearance by default or for unsupported values', () async {
    const store = AppearancePreferenceStore();

    expect(
      AppearancePreferenceStore.modeForCode('unknown'),
      AppearanceMode.light,
    );

    await store.setMode(AppearanceMode.dark);
    await store.setMode(AppearanceMode.light);
    final prefs = await SharedPreferences.getInstance();

    expect(await store.getMode(), AppearanceMode.light);
    expect(prefs.containsKey(AppearancePreferenceStore.preferenceKey), isFalse);
  });

  test('persists explicit skins', () async {
    const store = AppearancePreferenceStore();

    await store.setSkin(AppSkin.starry);
    final prefs = await SharedPreferences.getInstance();

    expect(await store.getSkin(), AppSkin.starry);
    expect(
      prefs.getString(AppearancePreferenceStore.skinPreferenceKey),
      'starry',
    );

    await store.setSkin(AppSkin.candy);
    expect(await store.getSkin(), AppSkin.candy);
    expect(
      prefs.getString(AppearancePreferenceStore.skinPreferenceKey),
      'candy',
    );

    await store.setSkin(AppSkin.fresh);
    expect(await store.getSkin(), AppSkin.fresh);
    expect(
      prefs.containsKey(AppearancePreferenceStore.skinPreferenceKey),
      isFalse,
    );
  });

  test('uses fresh skin when preference is cleared or unsupported', () async {
    const store = AppearancePreferenceStore();

    expect(AppearancePreferenceStore.skinForCode('unknown'), AppSkin.fresh);

    await store.setSkin(AppSkin.starry);
    await store.setSkin(AppSkin.fresh);
    final prefs = await SharedPreferences.getInstance();

    expect(await store.getSkin(), AppSkin.fresh);
    expect(
      prefs.containsKey(AppearancePreferenceStore.skinPreferenceKey),
      isFalse,
    );
  });
}
