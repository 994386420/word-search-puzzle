import 'package:flutter/widgets.dart';

import '../features/word_search/domain/models.dart';

class AppStrings {
  const AppStrings._(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static const supportedLocales = [Locale('en'), Locale('zh'), Locale('ko')];

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        const AppStrings._(Locale('en'));
  }

  bool get isZh => locale.languageCode == 'zh';
  bool get isKo => locale.languageCode == 'ko';

  String _t({required String en, required String zh, required String ko}) {
    if (isZh) {
      return zh;
    }
    if (isKo) {
      return ko;
    }
    return en;
  }

  String get appTitle => _t(en: 'Word Search', zh: '单词搜索', ko: '단어 찾기');
  String get playAndLearn => _t(en: 'Play & Learn', zh: '边玩边学', ko: '놀며 배우기');
  String get findWordsTitle => _t(en: 'Find Words', zh: '寻找单词', ko: '단어 찾기');
  String get pictureModeTitle =>
      _t(en: 'Picture Mode', zh: '图片模式', ko: '그림 모드');
  String get wordsThemesTitle => _t(en: 'Word Themes', zh: '单词主题', ko: '단어 테마');
  String get continueLearning =>
      _t(en: 'Continue Learning', zh: '继续学习', ko: '계속 배우기');
  String get chooseTheme => _t(en: 'Choose Theme', zh: '选择主题', ko: '테마 선택');
  String get adventureLevels => _t(en: 'Adventure', zh: '冒险关卡', ko: '모험 레벨');
  String get customPlay => _t(en: 'Free Play', zh: '自由玩', ko: '자유 플레이');
  String get playSettings => _t(en: 'Play settings', zh: '玩法设置', ko: '플레이 설정');
  String get chooseLevelPack =>
      _t(en: 'Choose a level pack', zh: '选择关卡主题', ko: '레벨 팩 선택');
  String get levelMap => _t(en: 'Level map', zh: '关卡地图', ko: '레벨 지도');
  String get seeHearFind => _t(
    en: 'See it · Hear it · Find it',
    zh: '看图 · 听音 · 找单词',
    ko: '보고 · 듣고 · 찾아요',
  );
  String get todayPuzzle => _t(en: "TODAY'S PUZZLE", zh: '今日谜题', ko: '오늘의 퍼즐');
  String get done => _t(en: 'DONE', zh: '完成', ko: '완료');
  String get gotIt => _t(en: 'Got it', zh: '知道了', ko: '알겠어요');
  String get preparingToday =>
      _t(en: 'Preparing today...', zh: '正在准备今日谜题...', ko: '오늘 퍼즐 준비 중...');
  String get daily => _t(en: 'Daily', zh: '每日', ko: '데일리');
  String get leaderboard => _t(en: 'LEADERBOARD', zh: '排行榜', ko: '리더보드');
  String get leaderboardFilters =>
      _t(en: 'RANKING FILTERS', zh: '榜单筛选', ko: '랭킹 필터');
  String get chooseCategory =>
      _t(en: 'Choose category', zh: '选择主题', ko: '카테고리 선택');
  String get chooseClueMode =>
      _t(en: 'Choose a clue', zh: '选择线索方式', ko: '힌트 방식을 골라요');
  String get chooseDifficulty =>
      _t(en: 'Choose difficulty', zh: '选择难度', ko: '난이도를 골라요');
  String get chooseGameMode =>
      _t(en: 'Choose a game mode', zh: '选择玩法', ko: '게임 모드를 골라요');
  String get recommended => _t(en: 'Recommended', zh: '推荐', ko: '추천');
  String completeThemeToUnlock(String theme) => _t(
    en: 'Finish $theme to unlock',
    zh: '完成$theme后解锁',
    ko: '$theme 완료 후 잠금 해제',
  );
  String completeThemeLevelsToUnlock(String theme, int levels) => _t(
    en: 'Clear $levels $theme levels to unlock',
    zh: '完成$theme $levels 关后解锁',
    ko: '$theme $levels레벨 완료 후 잠금 해제',
  );
  String get rewardedUnavailable => _t(
    en: 'The unlock video is not ready yet. Keep playing and try again later.',
    zh: '解锁视频还没有准备好，可以继续游戏后再试。',
    ko: '잠금 해제 영상이 아직 준비되지 않았어요. 나중에 다시 시도해 주세요.',
  );
  String get coins => _t(en: 'Coins', zh: '金币', ko: '코인');
  String get free => _t(en: 'Free', zh: '免费', ko: '무료');
  String get coinWallet => _t(en: 'Coin wallet', zh: '金币钱包', ko: '코인 지갑');
  String get earnCoinsByPlaying => _t(
    en: 'Clear levels and daily puzzles to earn more coins.',
    zh: '完成关卡和每日挑战即可获得更多金币。',
    ko: '레벨과 데일리 퍼즐을 완료해 코인을 모아요.',
  );
  String get hintsRefill => _t(en: 'Refill hints', zh: '补充提示', ko: '힌트 충전');
  String get notEnoughCoins =>
      _t(en: 'Not enough coins', zh: '金币不足', ko: '코인이 부족해요');
  String hintRefillBody(int count) => _t(
    en: 'Get $count more hints and keep this puzzle going.',
    zh: '补充 $count 个提示，继续完成这一关。',
    ko: '힌트 $count개를 충전하고 계속해요.',
  );
  String coinShortageBody(int cost, int balance) => _t(
    en: 'This hint costs $cost coins. You have $balance.',
    zh: '本次提示需要 $cost 金币，当前有 $balance 金币。',
    ko: '이 힌트는 $cost코인이 필요해요. 현재 $balance코인이 있어요.',
  );
  String spendCoins(int count) =>
      _t(en: 'Use $count coins', zh: '使用 $count 金币', ko: '$count코인 사용');
  String get watchForCoins => _t(
    en: 'Watch video for 60 coins',
    zh: '观看视频，获得 60 金币',
    ko: '영상 보고 60코인 받기',
  );
  String get watchForHints => _t(
    en: 'Watch video for 3 hints',
    zh: '观看视频，获得 3 个提示',
    ko: '영상 보고 힌트 3개 받기',
  );
  String coinReward(int count) =>
      _t(en: '+$count coins', zh: '+$count 金币', ko: '+$count코인');
  String get levelRewardClaimed => _t(
    en: 'First-clear reward claimed',
    zh: '本关首通奖励已领取',
    ko: '첫 클리어 보상 수령 완료',
  );
  String coinBalance(int count) =>
      _t(en: '$count coins total', zh: '共有 $count 金币', ko: '총 $count코인');
  String get unlockThemeBody => _t(
    en: 'Clear 5 levels in the previous theme, or watch one family-safe video to play this theme today.',
    zh: '完成上一个主题的 5 关，或观看一次儿童安全视频，即可在今天体验这个主题。',
    ko: '이전 테마 5레벨을 완료하거나 어린이용 영상을 한 번 보고 오늘 이 테마를 이용하세요.',
  );
  String get unlockThemeWithoutVideo => _t(
    en: 'Clear 5 levels in the previous theme to unlock this one. Video unlock is available in the Android and iOS app.',
    zh: '完成上一个主题的 5 关即可解锁。看视频解锁仅在 Android 和 iOS 应用中提供。',
    ko: '이전 테마 5레벨을 완료하면 잠금이 해제돼요. 영상 잠금 해제는 Android와 iOS 앱에서 이용할 수 있어요.',
  );
  String get watchToUnlock =>
      _t(en: 'Watch to unlock today', zh: '观看视频，今日解锁', ko: '영상 보고 오늘 잠금 해제');
  String get keepPlayingToUnlock =>
      _t(en: 'Keep playing to unlock', zh: '继续游戏自然解锁', ko: '계속 플레이해서 잠금 해제');
  String get failedLoadLeaderboard =>
      _t(en: 'Failed to load leaderboard', zh: '排行榜加载失败', ko: '리더보드 로드 실패');
  String get tryAgain => _t(en: 'Try again', zh: '重试', ko: '다시 시도');
  String get noScoresYet => _t(en: 'No scores yet', zh: '暂无成绩', ko: '아직 점수 없음');
  String get beFirstScore => _t(
    en: 'Be the first to complete this puzzle!',
    zh: '完成这一局，抢先登上榜单。',
    ko: '이 퍼즐을 완료하고 첫 점수를 남겨보세요!',
  );
  String get beFirstStarRank => _t(
    en: 'Complete campaign levels to join the star ranking.',
    zh: '完成关卡并收集星星，即可登上星星榜。',
    ko: '캠페인 레벨을 완료하고 별 랭킹에 참여하세요.',
  );
  String get allThemes => _t(en: 'All themes', zh: '全部主题', ko: '모든 테마');
  String get totalStarLeaderboard =>
      _t(en: 'Total stars', zh: '总星星榜', ko: '총 별 랭킹');
  String completedLevelCount(int completed, int total) => _t(
    en: '$completed/$total levels',
    zh: '完成 $completed/$total 关',
    ko: '$completed/$total 레벨 완료',
  );
  String get myStats => _t(en: 'MY STATS', zh: '我的统计', ko: '내 통계');
  String get noStatsYet => _t(en: 'No stats yet', zh: '暂无统计', ko: '아직 통계 없음');
  String get favoriteTheme =>
      _t(en: 'FAVORITE THEME', zh: '最常玩主题', ko: '가장 자주 한 테마');
  String get playAGame => _t(en: 'Play a game', zh: '先玩一局', ko: '한 판 플레이');
  String get startTracking => _t(
    en: 'Complete a puzzle to start tracking.',
    zh: '完成一局后开始记录。',
    ko: '퍼즐을 완료하면 기록이 시작됩니다.',
  );
  String get wordsFound => _t(en: 'Words Found', zh: '找到单词', ko: '찾은 단어');
  String get gamesDone => _t(en: 'Games Done', zh: '完成局数', ko: '완료한 게임');
  String get dailyDone => _t(en: 'Daily Done', zh: '每日完成', ko: '데일리 완료');
  String get bestTime => _t(en: 'Best Time', zh: '最佳时间', ko: '최고 기록');
  String get bestSpeed => _t(en: 'Best Speed', zh: '竞速最佳', ko: '최고 스피드');
  String get themesPlayed => _t(en: 'Themes Played', zh: '玩过主题', ko: '플레이한 테마');
  String get levelUp => _t(en: 'LEVEL UP', zh: '升级', ko: '레벨 업');
  String get traceAWord =>
      _t(en: 'Trace a word', zh: '划出一个单词', ko: '단어를 따라 그리세요');
  String get dragAcrossLetters => _t(
    en: 'Drag across connected letters.',
    zh: '沿着相连字母滑动。',
    ko: '이어진 글자를 따라 드래그하세요.',
  );
  String get greatFirstFind =>
      _t(en: 'Great first find!', zh: '第一个词找到了!', ko: '첫 단어를 찾았어요!');
  String get paused => _t(en: 'PAUSED', zh: '已暂停', ko: '일시정지');
  String get resume => _t(en: 'RESUME', zh: '继续', ko: '계속하기');
  String get useHint => _t(en: 'Use hint', zh: '使用提示', ko: '힌트 사용');
  String get pauseGame => _t(en: 'Pause game', zh: '暂停游戏', ko: '게임 일시정지');
  String get restartPuzzle =>
      _t(en: 'Restart puzzle', zh: '重新开始', ko: '퍼즐 다시 시작');
  String get perfect => _t(en: 'PERFECT!', zh: '完美!', ko: '완벽해요!');
  String get timesUp => _t(en: "TIME'S UP!", zh: '时间到!', ko: '시간 종료!');
  String get puzzleSolved =>
      _t(en: 'PUZZLE SOLVED!', zh: '谜题完成!', ko: '퍼즐 완료!');
  String get dailyChampion =>
      _t(en: 'Daily champion!', zh: '每日挑战冠军!', ko: '데일리 챔피언!');
  String get dailyPuzzleComplete =>
      _t(en: 'Daily puzzle complete!', zh: '今日谜题完成!', ko: '오늘 퍼즐 완료!');
  String get lightningFast =>
      _t(en: 'Lightning fast!', zh: '速度太快了!', ko: '번개처럼 빨라요!');
  String get greatSpeedRun =>
      _t(en: 'Great speed run!', zh: '竞速表现不错!', ko: '스피드런이 좋아요!');
  String get superFinder =>
      _t(en: 'Super finder!', zh: '找词高手!', ko: '단어 찾기 고수!');
  String get greatFocus =>
      _t(en: 'Great focus!', zh: '专注力很棒!', ko: '집중력이 좋아요!');
  String get nicePuzzleWork =>
      _t(en: 'Nice puzzle work!', zh: '解得不错!', ko: '퍼즐 실력이 좋아요!');
  String get found => _t(en: 'FOUND', zh: '找到', ko: '찾음');
  String get time => _t(en: 'TIME', zh: '时间', ko: '시간');
  String get score => _t(en: 'SCORE', zh: '分数', ko: '점수');
  String get words => _t(en: 'WORDS', zh: '单词', ko: '단어');
  String get mainMenu => _t(en: 'MAIN MENU', zh: '主菜单', ko: '메인 메뉴');
  String get settings => _t(en: 'SETTINGS', zh: '设置', ko: '설정');
  String get sound => _t(en: 'Sound', zh: '音效', ko: '사운드');
  String get soundEffects => _t(en: 'Sound effects', zh: '操作音效', ko: '효과음');
  String get haptics => _t(en: 'Haptics', zh: '震动', ko: '진동');
  String get voiceGuide => _t(en: 'Voice guide', zh: '语音引导', ko: '음성 안내');
  String get wordPronunciation =>
      _t(en: 'Word pronunciation', zh: '单词发音', ko: '단어 발음');
  String get replayGuide =>
      _t(en: 'Replay guide', zh: '重新播放引导', ko: '안내 다시 보기');
  String get appearance => _t(en: 'Appearance', zh: '外观', ko: '화면 모드');
  String get systemAppearance => _t(en: 'System', zh: '系统', ko: '시스템');
  String get lightAppearance => _t(en: 'Light', zh: '浅色', ko: '라이트');
  String get darkAppearance => _t(en: 'Dark', zh: '深色', ko: '다크');
  String get skin => _t(en: 'Skin', zh: '皮肤', ko: '스킨');
  String get freshSkin => _t(en: 'Fresh', zh: '清新', ko: '프레시');
  String get starrySkin => _t(en: 'Starry', zh: '星空', ko: '별빛');
  String get candySkin => _t(en: 'Candy', zh: '糖果', ko: '캔디');
  String get startGuideTitle =>
      _t(en: 'Pick a mode', zh: '先来一局', ko: '모드를 골라요');
  String get startGuideBody => _t(
    en: 'Classic is relaxed. Speed is timed.',
    zh: '普通轻松找词，竞速限时挑战。',
    ko: '클래식은 천천히, 스피드는 시간 도전.',
  );
  String get startGuideClassicHint =>
      _t(en: 'Relaxed play', zh: '轻松找词', ko: '천천히 찾기');
  String get startGuideSpeedHint =>
      _t(en: 'Timed run', zh: '限时挑战', ko: '시간 도전');
  String get roundWordsLearned =>
      _t(en: 'WORDS LEARNED', zh: '本局学到', ko: '이번 판 단어');
  String get tapWordAudio =>
      _t(en: 'Tap a word to hear it', zh: '点单词听发音', ko: '단어를 눌러 들어요');
  String get learning => _t(en: 'LEARNING', zh: '学习', ko: '학습');
  String get learnedWords => _t(en: 'Learned Words', zh: '已学单词', ko: '배운 단어');
  String get favoriteWords =>
      _t(en: 'Favorite Words', zh: '收藏单词', ko: '즐겨찾기 단어');
  String get recentWords => _t(en: 'Recent Words', zh: '最近学到', ko: '최근 단어');
  String get reviewWords => _t(en: 'Review Words', zh: '复习单词', ko: '단어 복습');
  String get allWords => _t(en: 'All', zh: '全部', ko: '전체');
  String get favorites => _t(en: 'Favorites', zh: '收藏', ko: '즐겨찾기');
  String get noLearnedWordsYet => _t(
    en: 'Find words in a puzzle to build your review list.',
    zh: '先在关卡里找到单词，这里会生成复习列表。',
    ko: '퍼즐에서 단어를 찾으면 복습 목록이 만들어져요.',
  );
  String get noFavoriteWordsYet => _t(
    en: 'Star words you want to review again.',
    zh: '点亮星标，把想复习的单词收藏起来。',
    ko: '다시 보고 싶은 단어에 별표를 눌러보세요.',
  );
  String get saveWord => _t(en: 'Save word', zh: '收藏单词', ko: '단어 저장');
  String get savedWord => _t(en: 'Saved word', zh: '已收藏', ko: '저장됨');
  String get lastSeen => _t(en: 'Last seen', zh: '最近', ko: '최근');
  String get language => _t(en: 'Language', zh: '语言', ko: '언어');
  String get systemLanguage => _t(en: 'System', zh: '系统', ko: '시스템');
  String get privacyOptions =>
      _t(en: 'Privacy options', zh: '隐私设置', ko: '개인정보 설정');
  String get parentSettings =>
      _t(en: 'Parent settings', zh: '家长设置', ko: '보호자 설정');
  String get viewStats => _t(en: 'View stats', zh: '查看统计', ko: '통계 보기');
  String get dailyChallenge =>
      _t(en: 'Daily Challenge', zh: '每日挑战', ko: '데일리 챌린지');
  String get comeBackTomorrow => _t(
    en: 'Come back tomorrow for a new daily puzzle',
    zh: '明天再来挑战新的每日谜题',
    ko: '내일 새로운 데일리 퍼즐에 도전하세요',
  );
  String get playAgain => _t(en: 'PLAY AGAIN', zh: '再玩一次', ko: '다시 플레이');
  String get dailyComplete =>
      _t(en: 'DAILY COMPLETE', zh: '每日完成', ko: '데일리 완료');
  String get savingStreak =>
      _t(en: 'Saving streak...', zh: '正在保存连续天数...', ko: '연속 기록 저장 중...');
  String get savingScore =>
      _t(en: 'Saving score...', zh: '正在保存成绩...', ko: '점수 저장 중...');
  String get viewLeaderboard =>
      _t(en: 'View Leaderboard', zh: '查看排行榜', ko: '리더보드 보기');
  String get saveYourScore =>
      _t(en: 'SAVE YOUR SCORE', zh: '保存成绩', ko: '점수 저장');
  String get creatingNickname =>
      _t(en: 'Creating nickname...', zh: '正在生成匿名昵称...', ko: '별명 만드는 중...');
  String get enterYourName =>
      _t(en: 'Enter your name', zh: '输入你的名字', ko: '이름 입력');
  String get failedSaveScore => _t(
    en: 'Failed to save, try again',
    zh: '保存失败，请重试',
    ko: '저장 실패, 다시 시도하세요',
  );
  String get speedRun => _t(en: '2:00 RUN', zh: '2:00 竞速', ko: '2:00 스피드런');
  String get completedPuzzle => _t(en: 'Complete', zh: '已完成', ko: '완료');
  String get nextLevel => _t(en: 'CONTINUE', zh: '继续挑战', ko: '계속 도전');
  String get learnedWord => _t(en: 'Learned', zh: '学到', ko: '배웠어요');
  String get rewards => _t(en: 'REWARDS', zh: '奖励', ko: '보상');
  String get roundDetails => _t(en: 'Round details', zh: '本局详情', ko: '라운드 상세');
  String get hideRoundDetails =>
      _t(en: 'Hide details', zh: '收起详情', ko: '상세 접기');
  String get rewardSaveFailed => _t(
    en: 'Reward details are temporarily unavailable.',
    zh: '奖励详情暂时无法读取。',
    ko: '보상 상세 정보를 불러올 수 없어요.',
  );
  String get totalStars => _t(en: 'Total Stars', zh: '累计星星', ko: '누적 별');
  String get badges => _t(en: 'Badges', zh: '徽章', ko: '배지');
  String get newBadgeUnlocked =>
      _t(en: 'New badge unlocked', zh: '解锁新徽章', ko: '새 배지 획득');
  String get noBadgesYet => _t(
    en: 'Keep playing to unlock badges.',
    zh: '继续游戏来解锁徽章。',
    ko: '계속 플레이하면 배지를 얻을 수 있어요.',
  );

  String clueModeLabel(ClueMode mode) => switch (mode) {
    ClueMode.words => _t(en: 'Words', zh: '文字', ko: '단어'),
    ClueMode.pictures => _t(en: 'Pictures', zh: '图片', ko: '그림'),
    ClueMode.sounds => _t(en: 'Sounds', zh: '听音', ko: '소리'),
    ClueMode.memory => _t(en: 'Memory', zh: '记忆', ko: '기억'),
  };

  String playWordAudio(String word) =>
      _t(en: 'Play $word', zh: '播放 $word 发音', ko: '$word 발음 듣기');

  String combo(int count) =>
      _t(en: '$count combo', zh: '$count 连击', ko: '$count 콤보');

  String get scoreAndLeaderboard =>
      _t(en: 'Score & leaderboard', zh: '成绩与排行榜', ko: '점수와 리더보드');

  String themeProgress(int completed, int total) => _t(
    en: '$completed/$total themes explored',
    zh: '已探索 $completed/$total 个主题',
    ko: '$completed/$total 테마 탐험',
  );

  String levelPackProgress(int completed, int total) => _t(
    en: '$completed/$total levels complete',
    zh: '已完成 $completed/$total 关',
    ko: '$completed/$total 레벨 완료',
  );

  String themeLevelSummary(int completed, int total) => _t(
    en: '$completed of $total levels complete',
    zh: '已完成 $completed/$total 关',
    ko: '$completed/$total 레벨 완료',
  );

  String nextThemeLevel(int level) =>
      _t(en: 'Next: Level $level', zh: '下一关：第 $level 关', ko: '다음: 레벨 $level');

  String completeLevelToUnlock(int level) => _t(
    en: 'Complete Level $level to unlock this level',
    zh: '请先完成第 $level 关，才能解锁此关',
    ko: '이 단계를 잠금 해제하려면 레벨 $level을 완료하세요',
  );

  String puzzleRuleSummary(PuzzleConfig config, ClueMode clueMode) {
    final clue = clueModeLabel(clueMode);
    final direction = switch (config.directionMode) {
      PuzzleDirectionMode.horizontal => _t(
        en: 'horizontal',
        zh: '横向',
        ko: '가로',
      ),
      PuzzleDirectionMode.forward => _t(
        en: 'two directions',
        zh: '横竖',
        ko: '가로세로',
      ),
      PuzzleDirectionMode.reverse => _t(
        en: 'reverse words',
        zh: '含反向',
        ko: '역방향',
      ),
      PuzzleDirectionMode.all => _t(en: 'diagonals', zh: '含斜向', ko: '대각선'),
    };
    return _t(
      en: '${config.gridSize}×${config.gridSize} · ${config.wordCount} words · $direction · $clue',
      zh: '${config.gridSize}×${config.gridSize} · ${config.wordCount} 个词 · $direction · $clue',
      ko: '${config.gridSize}×${config.gridSize} · ${config.wordCount}단어 · $direction · $clue',
    );
  }

  String unlockTheme(String theme) =>
      _t(en: 'Unlock $theme', zh: '解锁$theme', ko: '$theme 잠금 해제');

  String levelButton(int level) {
    return _t(en: 'Level $level', zh: '第 $level 关', ko: '레벨 $level');
  }

  String levelLabel(int level) => 'Lv $level';

  String levelProgress({
    required int level,
    required int current,
    required int total,
  }) {
    return _t(
      en: 'Lv $level · $current/$total words',
      zh: 'Lv $level · $current/$total 个词',
      ko: 'Lv $level · $current/$total 단어',
    );
  }

  String campaignProgress({
    required int level,
    required int themeLevel,
    required int completed,
    required int total,
  }) {
    return _t(
      en: 'Level $level · Stage $themeLevel · $completed/$total complete',
      zh: '第 $level 关 · 主题第 $themeLevel 关 · 已完成 $completed/$total',
      ko: '레벨 $level · 테마 $themeLevel단계 · $completed/$total 완료',
    );
  }

  String currentPuzzleProgress({required int found, required int total}) {
    return _t(
      en: 'Round $found/$total',
      zh: '本局 $found/$total',
      ko: '이번 판 $found/$total',
    );
  }

  String dailyStreak(int streak) {
    return _t(en: '$streak day streak', zh: '连续 $streak 天', ko: '$streak일 연속');
  }

  String dailyStreakWithNext(int streak, String nextDailyLabel) {
    return _t(
      en: '$streak day streak · next in $nextDailyLabel',
      zh: '连续 $streak 天 · 下次 $nextDailyLabel 后',
      ko: '$streak일 연속 · 다음까지 $nextDailyLabel',
    );
  }

  String completedRounds(int count) {
    return _t(
      en: '$count completed rounds',
      zh: '已完成 $count 局',
      ko: '$count판 완료',
    );
  }

  String categoryProgressSummary({
    required String categoryId,
    required int found,
    required int total,
  }) {
    return _t(
      en: '${categoryName(categoryId)} · $found/$total words',
      zh: '${categoryName(categoryId)} · $found/$total 个单词',
      ko: '${categoryName(categoryId)} · $found/$total 단어',
    );
  }

  String wordsLeft(int count) {
    return _t(en: '$count left', zh: '还差 $count 个', ko: '$count개 남음');
  }

  String ranked(int rank) =>
      _t(en: 'You ranked #$rank!', zh: '你排在第 $rank 名!', ko: '$rank위에 올랐어요!');

  String nextCategory(String categoryId) {
    final name = categoryName(categoryId);
    return _t(
      en: 'NEXT: ${name.toUpperCase()}',
      zh: '下一题: $name',
      ko: '다음: $name',
    );
  }

  String points(int points) =>
      _t(en: '+$points pts', zh: '+$points 分', ko: '+$points점');

  String starsEarned(int stars) {
    return _t(en: '+$stars stars', zh: '+$stars 颗星', ko: '+$stars개 별');
  }

  String timesFound(int count) {
    return _t(en: 'Found $count times', zh: '找到 $count 次', ko: '$count번 찾음');
  }

  String badgeName(String id) => switch (id) {
    'first_win' => _t(en: 'First Win', zh: '首次通关', ko: '첫 승리'),
    'star_collector' => _t(en: 'Star Collector', zh: '星星收藏家', ko: '별 수집가'),
    'daily_starter' => _t(en: 'Daily Starter', zh: '每日启程', ko: '데일리 시작'),
    'theme_explorer' => _t(en: 'Theme Explorer', zh: '主题探索家', ko: '테마 탐험가'),
    'speed_runner' => _t(en: 'Speed Runner', zh: '竞速选手', ko: '스피드 러너'),
    'word_hunter' => _t(en: 'Word Hunter', zh: '单词猎手', ko: '단어 사냥꾼'),
    _ => id,
  };

  String badgeDescription(String id) => switch (id) {
    'first_win' => _t(
      en: 'Complete your first game',
      zh: '完成第一局',
      ko: '첫 게임 완료',
    ),
    'star_collector' => _t(
      en: 'Collect 10 stars',
      zh: '累计 10 颗星',
      ko: '별 10개 모으기',
    ),
    'daily_starter' => _t(
      en: 'Finish a Daily puzzle',
      zh: '完成一次每日挑战',
      ko: '데일리 퍼즐 완료',
    ),
    'theme_explorer' => _t(
      en: 'Play 3 themes',
      zh: '玩过 3 个主题',
      ko: '테마 3개 플레이',
    ),
    'speed_runner' => _t(
      en: 'Score 1000 in Speed',
      zh: '竞速分数达到 1000',
      ko: '스피드 점수 1000 달성',
    ),
    'word_hunter' => _t(en: 'Find 50 words', zh: '找到 50 个单词', ko: '단어 50개 찾기'),
    _ => '',
  };

  String nextDailyLabel({required int hours, required int minutes}) {
    if (hours <= 0) {
      return _t(
        en: '${minutes.clamp(1, 59)}m',
        zh: '${minutes.clamp(1, 59)} 分钟',
        ko: '${minutes.clamp(1, 59)}분',
      );
    }
    return _t(
      en: '${hours}h ${minutes}m',
      zh: '$hours 小时 $minutes 分钟',
      ko: '$hours시간 $minutes분',
    );
  }

  String difficultyLabel(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => _t(en: 'Easy', zh: '简单', ko: '쉬움'),
    Difficulty.medium => _t(en: 'Medium', zh: '中等', ko: '보통'),
    Difficulty.hard => _t(en: 'Hard', zh: '困难', ko: '어려움'),
  };

  String difficultyShortLabel(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => _t(en: 'Easy', zh: '简单', ko: '쉬움'),
    Difficulty.medium => _t(en: 'Med', zh: '中等', ko: '보통'),
    Difficulty.hard => _t(en: 'Hard', zh: '困难', ko: '어려움'),
  };

  String modeLabel(GameMode mode) => switch (mode) {
    GameMode.classic => _t(en: 'Classic', zh: '普通', ko: '클래식'),
    GameMode.speed => _t(en: 'Speed', zh: '竞速', ko: '스피드'),
  };

  String leaderboardModeLabel(LeaderboardMode mode) => switch (mode) {
    LeaderboardMode.classic => _t(en: 'Classic', zh: '普通', ko: '클래식'),
    LeaderboardMode.speed => _t(en: 'Speed', zh: '竞速', ko: '스피드'),
    LeaderboardMode.stars => _t(en: 'Stars', zh: '星星', ko: '별'),
  };

  String modeTitle(GameMode mode) => switch (mode) {
    GameMode.classic => _t(en: 'Classic Mode', zh: '普通模式', ko: '클래식 모드'),
    GameMode.speed => _t(en: 'Speed Mode', zh: '竞速模式', ko: '스피드 모드'),
  };

  String categoryName(String id) => switch (id) {
    'animals' => _t(en: 'Animals', zh: '动物', ko: '동물'),
    'space' => _t(en: 'Space', zh: '太空', ko: '우주'),
    'sports' => _t(en: 'Sports', zh: '运动', ko: '스포츠'),
    'food' => _t(en: 'Food', zh: '美食', ko: '음식'),
    'tech' => _t(en: 'STEM', zh: '科学启蒙', ko: 'STEM'),
    'nature' => _t(en: 'Nature', zh: '自然', ko: '자연'),
    _ => id,
  };

  String categoryDescription(String id) => switch (id) {
    'animals' => _t(en: 'Safari & Wildlife', zh: '野生动物与探险', ko: '사파리와 야생동물'),
    'space' => _t(en: 'Cosmic Exploration', zh: '宇宙探索', ko: '우주 탐험'),
    'sports' => _t(en: 'Athletic Challenges', zh: '运动挑战', ko: '스포츠 챌린지'),
    'food' => _t(en: 'World Cuisine', zh: '世界美食', ko: '세계 음식'),
    'tech' => _t(en: 'Coding & Science', zh: '编程与科学', ko: '코딩과 과학'),
    'nature' => _t(en: "Earth's Wonders", zh: '地球奇观', ko: '지구의 경이'),
    _ => '',
  };

  String localizedError(String? message) {
    if ((!isZh && !isKo) || message == null || message.isEmpty) {
      return message ?? '';
    }
    final lower = message.toLowerCase();
    if (lower.contains('connection')) {
      return _t(
        en: message,
        zh: '网络连接异常，请稍后再试。',
        ko: '네트워크 연결을 확인하고 다시 시도하세요.',
      );
    }
    if (lower.contains('invalid response')) {
      return _t(en: message, zh: '排行榜返回异常，请稍后再试。', ko: '리더보드 응답이 올바르지 않습니다.');
    }
    if (lower.contains('wait') && lower.contains('submitting')) {
      final seconds = RegExp(r'(\d+)s').firstMatch(message)?.group(1);
      return seconds == null
          ? _t(
              en: message,
              zh: '提交太频繁，请稍后再试。',
              ko: '너무 자주 제출했습니다. 잠시 후 다시 시도하세요.',
            )
          : _t(
              en: message,
              zh: '请等待 $seconds 秒后再提交。',
              ko: '$seconds초 후 다시 제출하세요.',
            );
    }
    if (lower.contains('enter a name')) {
      return _t(en: message, zh: '请输入名字后再保存成绩。', ko: '점수를 저장하려면 이름을 입력하세요.');
    }
    if (lower.contains('20 characters')) {
      return _t(en: message, zh: '名字最多 20 个字符。', ko: '이름은 20자 이하여야 합니다.');
    }
    if (lower.contains('unsupported characters')) {
      return _t(en: message, zh: '名字包含不支持的字符。', ko: '이름에 지원하지 않는 문자가 있습니다.');
    }
    if (lower.contains('star progress could not be verified') ||
        lower.contains('score could not be verified') ||
        lower.contains('time could not be verified') ||
        lower.contains('incomplete') ||
        lower.contains('invalid')) {
      return _t(
        en: message,
        zh: '成绩校验失败，请重新完成一局。',
        ko: '점수 확인에 실패했습니다. 한 판을 다시 완료하세요.',
      );
    }
    if (lower.contains('load leaderboard')) {
      return _t(
        en: message,
        zh: '排行榜加载失败，请稍后再试。',
        ko: '리더보드 로드에 실패했습니다. 잠시 후 다시 시도하세요.',
      );
    }
    if (lower.contains('submit score')) {
      return _t(
        en: message,
        zh: '成绩提交失败，请稍后再试。',
        ko: '점수 제출에 실패했습니다. 잠시 후 다시 시도하세요.',
      );
    }
    return message;
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppStrings.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppStrings> load(Locale locale) async {
    final normalized = switch (locale.languageCode) {
      'zh' => const Locale('zh'),
      'ko' => const Locale('ko'),
      _ => const Locale('en'),
    };
    return AppStrings._(normalized);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
