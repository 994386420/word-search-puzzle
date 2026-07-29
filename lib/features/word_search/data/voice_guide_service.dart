import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VoiceGuideCue {
  homeIntro('home_intro'),
  chooseClassic('choose_classic'),
  chooseSpeed('choose_speed'),
  chooseDifficulty('choose_difficulty'),
  dailyReady('daily_ready'),
  gameIntro('game_intro'),
  hintUsed('hint_used'),
  firstFind('first_find'),
  tryAgain('try_again'),
  completion('completion'),
  dailyComplete('daily_complete'),
  reviewIntro('review_intro'),
  wordSaved('word_saved');

  const VoiceGuideCue(this.assetName);

  final String assetName;

  String localizedText(String languageCode) {
    final normalized = VoiceGuideService.normalizeLanguageCode(languageCode);
    return switch (normalized) {
      'zh' => switch (this) {
        VoiceGuideCue.homeIntro => '欢迎来到单词搜索。选择关卡、普通模式或竞速模式开始。',
        VoiceGuideCue.chooseClassic => '普通模式。选择主题和难度，找出所有隐藏单词。',
        VoiceGuideCue.chooseSpeed => '竞速模式。在倒计时结束前尽量找到更多单词。',
        VoiceGuideCue.chooseDifficulty => '选择简单、中等或困难。越难的单词分数越高。',
        VoiceGuideCue.dailyReady => '每日挑战已准备好。完成今日谜题，保持连续天数。',
        VoiceGuideCue.gameIntro => '按住字母并沿着单词方向滑动。',
        VoiceGuideCue.hintUsed => '提示来了。从发光字母开始，沿线找到单词。',
        VoiceGuideCue.firstFind => '很棒，找到第一个单词了。',
        VoiceGuideCue.tryAgain => '还差一点。试着沿着一条直线连接字母。',
        VoiceGuideCue.completion => '完成了，做得很好。',
        VoiceGuideCue.dailyComplete => '今日挑战完成，连续记录已更新。',
        VoiceGuideCue.reviewIntro => '在这里复习学过的单词。点喇叭听发音，点星标收藏。',
        VoiceGuideCue.wordSaved => '已加入复习收藏。',
      },
      'ko' => switch (this) {
        VoiceGuideCue.homeIntro => '단어 찾기에 오신 걸 환영해요. 레벨, 클래식, 스피드 중에서 시작해요.',
        VoiceGuideCue.chooseClassic => '클래식 모드예요. 테마와 난이도를 고르고 숨은 단어를 모두 찾아요.',
        VoiceGuideCue.chooseSpeed => '스피드 모드예요. 시간이 끝나기 전에 최대한 많은 단어를 찾아요.',
        VoiceGuideCue.chooseDifficulty =>
          '쉬움, 보통, 어려움 중에서 골라요. 어려운 단어일수록 점수가 높아요.',
        VoiceGuideCue.dailyReady => '데일리 챌린지가 준비됐어요. 오늘 퍼즐을 끝내고 연속 기록을 이어가요.',
        VoiceGuideCue.gameIntro => '글자를 누른 채 단어 방향으로 쭉 밀어보세요.',
        VoiceGuideCue.hintUsed => '힌트예요. 빛나는 글자에서 시작해서 단어를 따라가요.',
        VoiceGuideCue.firstFind => '좋아요. 첫 단어를 찾았어요.',
        VoiceGuideCue.tryAgain => '조금 아쉬워요. 한 줄로 이어진 글자를 찾아보세요.',
        VoiceGuideCue.completion => '완료했어요. 아주 잘했어요.',
        VoiceGuideCue.dailyComplete => '오늘 챌린지를 완료했어요. 연속 기록이 업데이트됐어요.',
        VoiceGuideCue.reviewIntro =>
          '배운 단어를 복습해요. 스피커를 누르면 발음을 듣고, 별표로 저장할 수 있어요.',
        VoiceGuideCue.wordSaved => '복습 단어로 저장했어요.',
      },
      _ => switch (this) {
        VoiceGuideCue.homeIntro =>
          'Welcome to Word Search. Choose your level, classic mode, or speed mode to start.',
        VoiceGuideCue.chooseClassic =>
          'Classic mode. Pick a theme and difficulty, then find every hidden word.',
        VoiceGuideCue.chooseSpeed =>
          'Speed mode. Find as many words as you can before the timer ends.',
        VoiceGuideCue.chooseDifficulty =>
          'Choose easy, medium, or hard. Harder words are worth more points.',
        VoiceGuideCue.dailyReady =>
          'Daily challenge is ready. Complete today’s puzzle to keep your streak.',
        VoiceGuideCue.gameIntro =>
          'Press a letter, then drag along the word direction.',
        VoiceGuideCue.hintUsed =>
          'Here is a hint. Start from the glowing letter and trace the word.',
        VoiceGuideCue.firstFind => 'Great. You found your first word.',
        VoiceGuideCue.tryAgain =>
          'Not quite. Try connected letters in one straight line.',
        VoiceGuideCue.completion => 'Puzzle complete. Nice work.',
        VoiceGuideCue.dailyComplete =>
          'Daily challenge complete. Your streak is updated.',
        VoiceGuideCue.reviewIntro =>
          'Review your learned words. Tap the speaker to hear pronunciation, or star words to save them.',
        VoiceGuideCue.wordSaved => 'Saved for review.',
      },
    };
  }
}

class VoiceGuideBubble {
  const VoiceGuideBubble({
    required this.id,
    required this.text,
    required this.cue,
  });

  final int id;
  final String text;
  final VoiceGuideCue cue;
}

class VoiceGuideService {
  VoiceGuideService._();

  static final VoiceGuideService instance = VoiceGuideService._();
  static const _guideEnabledKey = 'voice_guide_enabled';
  static const _wordAudioEnabledKey = 'word_audio_enabled';

  final bubbleListenable = ValueNotifier<VoiceGuideBubble?>(null);
  final activeWordListenable = ValueNotifier<String?>(null);
  AudioPlayer? _player;
  bool? _cachedGuideEnabled;
  bool? _cachedWordAudioEnabled;
  Future<void> _playChain = Future<void>.value();
  final Map<String, DateTime> _lastPlayedAt = {};
  Timer? _bubbleTimer;
  Timer? _activeWordTimer;
  String _languageCode = 'en';
  int _bubbleId = 0;
  int _playGeneration = 0;
  bool _busy = false;

  static String normalizeLanguageCode(String languageCode) {
    return switch (languageCode.trim().toLowerCase()) {
      'zh' || 'zh_cn' || 'zh-cn' || 'zh_hans' || 'zh-hans' => 'zh',
      'ko' || 'ko_kr' || 'ko-kr' => 'ko',
      _ => 'en',
    };
  }

  void setLanguageCode(String languageCode) {
    _languageCode = normalizeLanguageCode(languageCode);
  }

  Future<bool> isEnabled() async {
    return isGuideEnabled();
  }

  Future<bool> isGuideEnabled() async {
    final cached = _cachedGuideEnabled;
    if (cached != null) {
      return cached;
    }
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_guideEnabledKey) ?? true;
    _cachedGuideEnabled = enabled;
    return enabled;
  }

  Future<bool> isWordAudioEnabled() async {
    final cached = _cachedWordAudioEnabled;
    if (cached != null) {
      return cached;
    }
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_wordAudioEnabledKey) ?? true;
    _cachedWordAudioEnabled = enabled;
    return enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    await setGuideEnabled(enabled);
  }

  Future<void> setGuideEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guideEnabledKey, enabled);
    _cachedGuideEnabled = enabled;
    if (!enabled) {
      _hideBubble();
      await _player?.stop();
    }
  }

  Future<void> setWordAudioEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wordAudioEnabledKey, enabled);
    _cachedWordAudioEnabled = enabled;
    if (!enabled) {
      _activeWordTimer?.cancel();
      activeWordListenable.value = null;
      await _player?.stop();
    }
  }

  Future<void> playCue(
    VoiceGuideCue cue, {
    bool interrupt = false,
    Duration? minInterval,
    bool skipIfBusy = false,
  }) {
    return _playAssetCandidates(
      _guideAssetCandidates(cue),
      bubble: VoiceGuideBubble(
        id: ++_bubbleId,
        text: cue.localizedText(_languageCode),
        cue: cue,
      ),
      dedupeKey: cue.assetName,
      isPlaybackAllowed: isGuideEnabled,
      interrupt: interrupt,
      minInterval: minInterval,
      skipIfBusy: skipIfBusy,
    );
  }

  Future<void> playWord(String word, {bool interrupt = true}) {
    final normalized = word.trim().toLowerCase();
    if (normalized.isEmpty) {
      return Future<void>.value();
    }
    return _playAssetCandidates(
      ['assets/audio/words/$normalized.mp3'],
      activeWord: normalized.toUpperCase(),
      isPlaybackAllowed: isWordAudioEnabled,
      interrupt: interrupt,
    );
  }

  Future<void> playFoundWord(String word) async {
    await playWord(word, interrupt: true);
    await playCue(VoiceGuideCue.firstFind);
  }

  List<String> _guideAssetCandidates(VoiceGuideCue cue) {
    if (_languageCode == 'en') {
      return ['assets/audio/guide/${cue.assetName}.mp3'];
    }
    return [
      'assets/audio/guide/$_languageCode/${cue.assetName}.mp3',
      'assets/audio/guide/${cue.assetName}.mp3',
    ];
  }

  Future<void> _playAssetCandidates(
    List<String> assetPaths, {
    required Future<bool> Function() isPlaybackAllowed,
    VoiceGuideBubble? bubble,
    String? activeWord,
    String? dedupeKey,
    bool interrupt = false,
    Duration? minInterval,
    bool skipIfBusy = false,
  }) async {
    if (assetPaths.isEmpty) {
      return;
    }
    if (!await isPlaybackAllowed()) {
      return;
    }
    if (skipIfBusy && _busy) {
      return;
    }
    final now = DateTime.now();
    final key = dedupeKey ?? assetPaths.first;
    final previous = _lastPlayedAt[key];
    if (previous != null &&
        minInterval != null &&
        now.difference(previous) < minInterval) {
      return;
    }
    _lastPlayedAt[key] = now;
    if (interrupt) {
      _playGeneration += 1;
      _playChain = Future<void>.value();
      await _player?.stop();
    }
    if (bubble != null) {
      _showBubble(bubble);
    }
    if (activeWord != null) {
      _showActiveWord(activeWord);
    }
    final generation = _playGeneration;
    _playChain = _playChain.catchError((_) {}).then((_) async {
      if (generation != _playGeneration || !await isPlaybackAllowed()) {
        _scheduleActiveWordClear(activeWord);
        return;
      }
      _busy = true;
      try {
        final player = _player ??= AudioPlayer();
        for (final assetPath in assetPaths) {
          try {
            await player.stop();
            await player.setAsset(assetPath);
            await player.play();
            return;
          } catch (_) {
            continue;
          }
        }
      } catch (_) {
        // Audio assets are optional in early builds; missing files should never
        // block the puzzle flow.
      } finally {
        if (generation == _playGeneration) {
          _busy = false;
        }
        _scheduleActiveWordClear(activeWord);
      }
    });
    return _playChain;
  }

  void _showBubble(VoiceGuideBubble bubble) {
    bubbleListenable.value = bubble;
    _bubbleTimer?.cancel();
    final milliseconds = (2200 + bubble.text.length * 52).clamp(2800, 5600);
    _bubbleTimer = Timer(Duration(milliseconds: milliseconds.toInt()), () {
      if (bubbleListenable.value?.id == bubble.id) {
        bubbleListenable.value = null;
      }
    });
  }

  void _hideBubble() {
    _bubbleTimer?.cancel();
    bubbleListenable.value = null;
  }

  void _showActiveWord(String word) {
    _activeWordTimer?.cancel();
    activeWordListenable.value = word;
  }

  void _scheduleActiveWordClear(String? word) {
    if (word == null || activeWordListenable.value != word) {
      return;
    }
    _activeWordTimer?.cancel();
    _activeWordTimer = Timer(const Duration(milliseconds: 720), () {
      if (activeWordListenable.value == word) {
        activeWordListenable.value = null;
      }
    });
  }

  Future<void> stop() async {
    _playGeneration += 1;
    _playChain = Future<void>.value();
    _hideBubble();
    _activeWordTimer?.cancel();
    activeWordListenable.value = null;
    try {
      await _player?.stop();
    } catch (_) {
      // Stopping voice should never block navigation.
    } finally {
      _busy = false;
    }
  }
}
