import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

class AdService extends ChangeNotifier {
  AdService._();

  static final AdService instance = AdService._();
  static const _interstitialMinCompletions = 3;
  static const _interstitialCooldown = Duration(seconds: 90);

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  Future<void>? _rewardedLoading;
  bool _initialized = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  Future<void>? _initializing;
  int _completedSinceInterstitial = 0;
  DateTime? _lastInterstitialShownAt;

  bool get isSupported => AdConfig.isMobileAdsSupported;
  bool get initialized => _initialized;
  bool get privacyOptionsRequired => _privacyOptionsRequired;
  bool get rewardedReady => _rewardedAd != null;

  Future<void> initialize() {
    if (_initializing != null) {
      return _initializing!;
    }
    _initializing = _initialize();
    return _initializing!;
  }

  Future<void> _initialize() async {
    if (!isSupported) {
      return;
    }

    final consentSucceeded = await _requestConsent();
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    _privacyOptionsRequired =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;

    final canInitializeAds =
        _canRequestAds || (!kReleaseMode && !consentSucceeded);
    if (!canInitializeAds) {
      notifyListeners();
      return;
    }

    if (!_canRequestAds && !kReleaseMode) {
      debugPrint(
        'AdService: UMP consent request failed; initializing test ads in non-release mode.',
      );
    }

    await MobileAds.instance.updateRequestConfiguration(
      AdConfig.familySafeRequestConfiguration,
    );
    await MobileAds.instance.initialize();
    _initialized = true;
    notifyListeners();
    unawaited(loadInterstitial());
    unawaited(loadRewarded());
  }

  Future<bool> _requestConsent() {
    final completer = Completer<bool>();
    void complete(bool value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      AdConfig.familySafeConsentRequestParameters,
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null) {
            debugPrint('AdService: consent form error: ${formError.message}');
          }
          complete(formError == null);
        });
      },
      (formError) {
        debugPrint('AdService: consent info error: ${formError.message}');
        complete(false);
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint('AdService: consent request timed out.');
        return false;
      },
    );
  }

  Future<void> showPrivacyOptions() async {
    if (!isSupported) {
      return;
    }
    await ConsentForm.showPrivacyOptionsForm((formError) {});
    _privacyOptionsRequired =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    notifyListeners();
  }

  Future<void> loadInterstitial() async {
    if (!_initialized || _interstitialAd != null) {
      return;
    }

    await InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              unawaited(loadInterstitial());
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              unawaited(loadInterstitial());
            },
          );
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> loadRewarded() {
    final unitId = AdConfig.rewardedUnitId;
    if (!_initialized || _rewardedAd != null || unitId == null) {
      return Future<void>.value();
    }
    final loading = _rewardedLoading;
    if (loading != null) {
      return loading;
    }
    final future = _loadRewarded(unitId);
    _rewardedLoading = future;
    return future.whenComplete(() => _rewardedLoading = null);
  }

  Future<void> _loadRewarded(String unitId) async {
    await RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          notifyListeners();
        },
      ),
    );
  }

  Future<bool> showRewardedUnlock() async {
    if (!_initialized) {
      return false;
    }
    if (_rewardedAd == null) {
      await loadRewarded();
    }
    final ad = _rewardedAd;
    if (ad == null) {
      return false;
    }
    _rewardedAd = null;
    notifyListeners();
    var earned = false;
    final completer = Completer<bool>();
    void complete() {
      if (!completer.isCompleted) {
        completer.complete(earned);
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        complete();
        unawaited(loadRewarded());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        complete();
        unawaited(loadRewarded());
      },
    );
    await ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
      },
    );
    return completer.future;
  }

  void registerGameCompleted() {
    if (!isSupported) {
      return;
    }
    _completedSinceInterstitial += 1;
    if (_initialized && _interstitialAd == null) {
      unawaited(loadInterstitial());
    }
  }

  Future<bool> showInterstitialIfAvailable() async {
    final ad = _interstitialAd;
    if (!_initialized || ad == null || !_canShowInterstitialNow()) {
      unawaited(loadInterstitial());
      return false;
    }
    _interstitialAd = null;
    _completedSinceInterstitial = 0;
    _lastInterstitialShownAt = DateTime.now();
    await ad.show();
    return true;
  }

  bool _canShowInterstitialNow() {
    if (_completedSinceInterstitial < _interstitialMinCompletions) {
      return false;
    }
    final lastShownAt = _lastInterstitialShownAt;
    if (lastShownAt == null) {
      return true;
    }
    return DateTime.now().difference(lastShownAt) >= _interstitialCooldown;
  }
}
