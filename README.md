# Word Search Puzzle

A Flutter word search game with classic and speed modes, local progress,
leaderboards, and AdMob integration.

## Development

V1 builds are ad-free in every build mode. The dormant AdMob integration uses
Google test IDs in debug only after ads are explicitly re-enabled in source.

```sh
/Users/mac/Desktop/flutter/bin/flutter analyze --no-fatal-infos
/Users/mac/Desktop/flutter/bin/flutter test
/Users/mac/Desktop/flutter/bin/flutter build apk --debug
```

## AI Image Generation

The project includes an OpenAI-compatible image generation CLI. Keep the API
key in the environment; never add it to Flutter source or commit it.

```sh
export OPENAI_API_KEY="your-api-key"
python3 tool/generate_image.py \
  "一张极简科技感海报，蓝绿色渐变背景，主体是发光的 AI 图片工作台" \
  --name ai-workbench-poster
```


## Android Release Checklist

The permanent Android application ID is `com.cw.wordsearch`.
Mobile V1 is portrait-only on Android, iPhone, and iPad.

1. Keep the upload keystore and its password file outside source control.
2. Point `android/key.properties` at those files using the
   `storePasswordFile`, `keyPasswordFile`, `keyAlias`, and `storeFile` keys.
3. Back up both the upload keystore and password file in a secure location.
4. Verify the release bundle:

```sh
/Users/mac/Desktop/flutter/bin/flutter build appbundle --release
```

Release builds intentionally fail when `android/key.properties`, the keystore,
or either signing secret is missing.

## AdMob Checklist

V1 is intentionally ad-free. The existing AdMob implementation and SDK remain
in the project for a later release, but `AdConfig.adsEnabled` is source-locked
to `false`. V1 does not initialize Mobile Ads and hides banner, interstitial,
rewarded, and AdMob privacy-option entry points.

The V1 platform manifests also remove Android advertising ID and Privacy
Sandbox advertising permissions, and iOS does not declare tracking usage.

Before a future ad-enabled release:

1. Set `AdConfig.adsEnabled` to `true`.
2. Restore only the Android advertising permissions the chosen ad setup needs.
3. Add an iOS tracking usage description only if the app actually requests
   App Tracking Transparency authorization.
4. Provide production rewarded unit IDs through
   `ADMOB_ANDROID_REWARDED_ID` and `ADMOB_IOS_REWARDED_ID`.
5. Publish `app-ads.txt` on the developer website.
6. Complete AdMob Privacy & messaging and the relevant store data-safety
   disclosures.
7. Re-run the family-safety and consent review, and never tap real ads during
   testing.

- Android app ID is configured in `android/app/build.gradle.kts`.
- Android banner and interstitial unit IDs are configured in
  `lib/features/word_search/data/ad_config.dart`.
- When ads are re-enabled, debug builds use Google test IDs to avoid invalid
  traffic.

## Leaderboard Backend Checklist

The Flutter client validates obvious mistakes before submitting scores, but
client-side checks are not anti-cheat. The Supabase function must also enforce:

- allowed `mode`, `category`, and `difficulty` values;
- player name trimming, length limits, and blocked characters/words;
- score range based on the actual category and difficulty word list;
- classic scores must equal the full puzzle score;
- speed times must be between `0` and `120` seconds;
- per-device or per-IP submit rate limits;
- a maximum number of stored entries per board;
- structured error responses such as `{ "error": "Name is not allowed" }`.
