import 'package:flutter_test/flutter_test.dart';
import 'package:word_search_puzzle/features/word_search/data/voice_guide_service.dart';

void main() {
  test('normalizes supported voice guide language codes', () {
    expect(VoiceGuideService.normalizeLanguageCode('zh-CN'), 'zh');
    expect(VoiceGuideService.normalizeLanguageCode('ko-KR'), 'ko');
    expect(VoiceGuideService.normalizeLanguageCode('fr-FR'), 'en');
  });

  test('returns localized cue bubble text', () {
    expect(VoiceGuideCue.homeIntro.localizedText('zh'), contains('欢迎来到单词搜索'));
    expect(VoiceGuideCue.reviewIntro.localizedText('ko'), contains('배운 단어'));
    expect(VoiceGuideCue.tryAgain.localizedText('en'), contains('Not quite'));
  });
}
