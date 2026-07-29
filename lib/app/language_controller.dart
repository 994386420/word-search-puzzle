import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../features/word_search/data/language_preference_store.dart';

class LanguageController extends ChangeNotifier {
  LanguageController({required LanguagePreferenceStore store}) : _store = store;

  static final LanguageController instance = LanguageController(
    store: const LanguagePreferenceStore(),
  );

  final LanguagePreferenceStore _store;
  Future<void>? _loadFuture;
  Locale? _locale;
  bool _loaded = false;

  Locale? get locale => _locale;
  bool get loaded => _loaded;
  String get selectedCode => _locale?.languageCode ?? 'system';

  Future<void> load() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    _locale = await _store.getLocale();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    final normalized = LanguagePreferenceStore.localeForCode(
      locale?.languageCode,
    );
    if (_locale?.languageCode == normalized?.languageCode) {
      return;
    }
    _locale = normalized;
    _loaded = true;
    notifyListeners();
    await _store.setLocale(normalized);
  }
}
