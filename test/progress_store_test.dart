import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_search_puzzle/features/word_search/data/progress_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reset guide state clears review voice guide state', () async {
    final store = ProgressStore();

    await store.markReviewVoiceGuideSeen();
    expect(await store.hasSeenReviewVoiceGuide(), isTrue);

    await store.resetGuideState();
    expect(await store.hasSeenReviewVoiceGuide(), isFalse);
  });
}
