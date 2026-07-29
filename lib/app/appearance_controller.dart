import 'package:flutter/material.dart';

import '../features/word_search/data/appearance_preference_store.dart';

class AppearanceController extends ChangeNotifier {
  AppearanceController({required AppearancePreferenceStore store})
    : _store = store;

  static final AppearanceController instance = AppearanceController(
    store: const AppearancePreferenceStore(),
  );

  final AppearancePreferenceStore _store;
  Future<void>? _loadFuture;
  AppearanceMode _mode = AppearanceMode.light;
  AppSkin _skin = AppSkin.fresh;
  bool _loaded = false;

  AppearanceMode get mode => _mode;
  AppSkin get skin => _skin;
  bool get loaded => _loaded;

  ThemeMode get themeMode => switch (_mode) {
    AppearanceMode.system => ThemeMode.system,
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark => ThemeMode.dark,
  };

  Future<void> load() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    _mode = await _store.getMode();
    _skin = await _store.getSkin();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(AppearanceMode mode) async {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    _loaded = true;
    notifyListeners();
    await _store.setMode(mode);
  }

  Future<void> setSkin(AppSkin skin) async {
    if (_skin == skin) {
      return;
    }
    _skin = skin;
    _loaded = true;
    notifyListeners();
    await _store.setSkin(skin);
  }
}
