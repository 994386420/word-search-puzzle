import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConfig {
  const AdConfig._();

  // V1 is intentionally ad-free. Change this source value only in a later
  // monetized release after restoring the platform advertising declarations.
  static const adsEnabled = false;

  static const _realAndroidAppId = 'ca-app-pub-4013657131703981~5892899586';
  static const _testAndroidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const _testIosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const _realAndroidBanner = 'ca-app-pub-4013657131703981/2615964169';
  static const _testAndroidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testIosBanner = 'ca-app-pub-3940256099942544/2934735716';

  static const _realAndroidInterstitial =
      'ca-app-pub-4013657131703981/6439694496';
  static const _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testIosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const _testAndroidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testIosRewarded = 'ca-app-pub-3940256099942544/1712485313';
  static const _realAndroidRewarded = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_ID',
  );
  static const _realIosRewarded = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_ID',
  );

  static bool get useRealAds => kReleaseMode;

  static String get androidAppId {
    return useRealAds ? _realAndroidAppId : _testAndroidAppId;
  }

  static String get iosAppId => _testIosAppId;

  static bool get isMobileAdsSupported {
    if (!adsEnabled || kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static RequestConfiguration get familySafeRequestConfiguration {
    return RequestConfiguration(
      maxAdContentRating: MaxAdContentRating.g,
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
    );
  }

  static ConsentRequestParameters get familySafeConsentRequestParameters {
    return ConsentRequestParameters(tagForUnderAgeOfConsent: true);
  }

  static String get bannerUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _testIosBanner;
    }
    return useRealAds ? _realAndroidBanner : _testAndroidBanner;
  }

  static String get interstitialUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _testIosInterstitial;
    }
    return useRealAds ? _realAndroidInterstitial : _testAndroidInterstitial;
  }

  static String? get rewardedUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (!useRealAds) {
        return _testIosRewarded;
      }
      return _realIosRewarded.isEmpty ? null : _realIosRewarded;
    }
    if (!useRealAds) {
      return _testAndroidRewarded;
    }
    return _realAndroidRewarded.isEmpty ? null : _realAndroidRewarded;
  }
}
