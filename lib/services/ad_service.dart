// --- START: CORRECT AND COMPLETE ad_service.dart ---
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService extends ChangeNotifier {
  RewardedAd? _rewardedAd;
  bool _isAdReady = false;

  bool get isAdReady => _isAdReady;

  final String _adUnitId = defaultTargetPlatform == TargetPlatform.android
      ? 'ca-app-pub-6347197985985593/6834202357' // Android Production ID
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS Test ID

  void loadRewardedAd() {
    if (_isAdReady) return;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('Rewarded ad loaded.');
          _rewardedAd = ad;
          _isAdReady = true;
          notifyListeners();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Rewarded ad failed to load: $error');
          _isAdReady = false;
          notifyListeners();
        },
      ),
    );
  }

  void showRewardedAd({
    required Function() onAdDismissed,
    required Function(RewardItem reward) onUserEarnedReward,
  }) {
    if (!_isAdReady || _rewardedAd == null) {
      debugPrint("Ad not ready.");
      loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) => debugPrint('Ad showed full screen.'),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _isAdReady = false;
        notifyListeners();
        onAdDismissed();
        loadRewardedAd(); // Pre-load the next ad
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _isAdReady = false;
        notifyListeners();
        loadRewardedAd(); // Pre-load the next ad
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onUserEarnedReward(reward);
      },
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }
}
// --- END: CORRECT AND COMPLETE ad_service.dart ---