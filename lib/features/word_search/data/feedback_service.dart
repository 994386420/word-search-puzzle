import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_guide_service.dart';

class FeedbackSettings {
  const FeedbackSettings({
    required this.soundEnabled,
    required this.hapticsEnabled,
    required this.voiceGuideEnabled,
    required this.wordAudioEnabled,
  });

  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool voiceGuideEnabled;
  final bool wordAudioEnabled;

  FeedbackSettings copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? voiceGuideEnabled,
    bool? wordAudioEnabled,
  }) {
    return FeedbackSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      voiceGuideEnabled: voiceGuideEnabled ?? this.voiceGuideEnabled,
      wordAudioEnabled: wordAudioEnabled ?? this.wordAudioEnabled,
    );
  }
}

class FeedbackService {
  const FeedbackService._();

  static const instance = FeedbackService._();
  static const _soundEnabledKey = 'feedback_sound_enabled';
  static const _hapticsEnabledKey = 'feedback_haptics_enabled';
  static const _voiceGuideEnabledKey = 'voice_guide_enabled';
  static const _wordAudioEnabledKey = 'word_audio_enabled';
  static FeedbackSettings? _cachedSettings;

  Future<FeedbackSettings> getSettings() async {
    final cached = _cachedSettings;
    if (cached != null) {
      return cached;
    }
    final prefs = await SharedPreferences.getInstance();
    final settings = FeedbackSettings(
      soundEnabled: prefs.getBool(_soundEnabledKey) ?? true,
      hapticsEnabled: prefs.getBool(_hapticsEnabledKey) ?? true,
      voiceGuideEnabled: prefs.getBool(_voiceGuideEnabledKey) ?? true,
      wordAudioEnabled: prefs.getBool(_wordAudioEnabledKey) ?? true,
    );
    _cachedSettings = settings;
    return settings;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
    final current = await getSettings();
    _cachedSettings = current.copyWith(soundEnabled: enabled);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsEnabledKey, enabled);
    final current = await getSettings();
    _cachedSettings = current.copyWith(hapticsEnabled: enabled);
  }

  Future<void> setVoiceGuideEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceGuideEnabledKey, enabled);
    await VoiceGuideService.instance.setGuideEnabled(enabled);
    final current = await getSettings();
    _cachedSettings = current.copyWith(voiceGuideEnabled: enabled);
  }

  Future<void> setWordAudioEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wordAudioEnabledKey, enabled);
    await VoiceGuideService.instance.setWordAudioEnabled(enabled);
    final current = await getSettings();
    _cachedSettings = current.copyWith(wordAudioEnabled: enabled);
  }

  Future<void> wordFound() async {
    await _lightImpact();
    await _click();
  }

  Future<void> wrongSelection() async {
    await _selectionClick();
  }

  Future<void> success() async {
    await _mediumImpact();
    await _alert();
  }

  Future<void> levelUp() async {
    await _heavyImpact();
    await _alert();
  }

  Future<void> tap() async {
    await _selectionClick();
  }

  Future<void> _selectionClick() async {
    if (kIsWeb || !(await getSettings()).hapticsEnabled) {
      return;
    }
    await HapticFeedback.selectionClick();
  }

  Future<void> _lightImpact() async {
    if (kIsWeb || !(await getSettings()).hapticsEnabled) {
      return;
    }
    await HapticFeedback.lightImpact();
  }

  Future<void> _mediumImpact() async {
    if (kIsWeb || !(await getSettings()).hapticsEnabled) {
      return;
    }
    await HapticFeedback.mediumImpact();
  }

  Future<void> _heavyImpact() async {
    if (kIsWeb || !(await getSettings()).hapticsEnabled) {
      return;
    }
    await HapticFeedback.heavyImpact();
  }

  Future<void> _click() async {
    if (kIsWeb || !(await getSettings()).soundEnabled) {
      return;
    }
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> _alert() async {
    if (kIsWeb || !(await getSettings()).soundEnabled) {
      return;
    }
    await SystemSound.play(SystemSoundType.alert);
  }
}
