import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/feedback_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists feedback settings', () async {
    const service = FeedbackService.instance;

    await service.setSoundEnabled(false);
    await service.setHapticsEnabled(false);
    await service.setVoiceGuideEnabled(false);
    await service.setWordAudioEnabled(false);
    final settings = await service.getSettings();
    final prefs = await SharedPreferences.getInstance();

    expect(settings.soundEnabled, isFalse);
    expect(settings.hapticsEnabled, isFalse);
    expect(settings.voiceGuideEnabled, isFalse);
    expect(settings.wordAudioEnabled, isFalse);
    expect(prefs.getBool('feedback_sound_enabled'), isFalse);
    expect(prefs.getBool('feedback_haptics_enabled'), isFalse);
    expect(prefs.getBool('voice_guide_enabled'), isFalse);
    expect(prefs.getBool('word_audio_enabled'), isFalse);
  });
}
