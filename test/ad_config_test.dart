import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:word_search_puzzle/features/word_search/data/ad_config.dart';

void main() {
  test('keeps ads disabled for the first release by default', () {
    expect(AdConfig.adsEnabled, isFalse);
    expect(AdConfig.isMobileAdsSupported, isFalse);
  });

  test('uses family-safe defaults for ad requests', () {
    final configuration = AdConfig.familySafeRequestConfiguration;

    expect(configuration.maxAdContentRating, MaxAdContentRating.g);
    expect(
      configuration.tagForChildDirectedTreatment,
      TagForChildDirectedTreatment.yes,
    );
    expect(configuration.tagForUnderAgeOfConsent, TagForUnderAgeOfConsent.yes);
  });

  test('uses under-age-of-consent treatment for UMP consent requests', () {
    final parameters = AdConfig.familySafeConsentRequestParameters;

    expect(parameters.tagForUnderAgeOfConsent, isTrue);
  });

  test('v1 platform manifests do not request advertising identifiers', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final iosInfoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    for (final permission in [
      'com.google.android.gms.permission.AD_ID',
      'android.permission.ACCESS_ADSERVICES_AD_ID',
      'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
      'android.permission.ACCESS_ADSERVICES_TOPICS',
    ]) {
      expect(androidManifest, contains(permission));
    }
    expect(
      RegExp(r'tools:node="remove"').allMatches(androidManifest),
      hasLength(4),
    );
    expect(iosInfoPlist, isNot(contains('NSUserTrackingUsageDescription')));
  });
}
