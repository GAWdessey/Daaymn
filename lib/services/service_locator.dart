// --- START: CORRECT AND COMPLETE service_locator.dart ---
import 'dart:developer';
import 'package:daaymn/in_app_purchase_service.dart';
import 'package:daaymn/services/ad_service.dart';
import 'package:daaymn/services/batch_service.dart';
import 'package:daaymn/services/message_cache_service.dart';
import 'package:daaymn/services/promo_code_service.dart';
import 'package:daaymn/utils/network_utils.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_pkg;
import 'package:daaymn/services/profile_provider.dart';

final getIt = GetIt.instance;

class ServiceLocator {
  supabase_pkg.SupabaseClient get supabaseClient => getIt<supabase_pkg.SupabaseClient>();
  BatchService get batchService => getIt<BatchService>();
  NetworkUtils get networkUtils => getIt<NetworkUtils>();
  MessageCacheService get messageCache => getIt<MessageCacheService>();
  InAppPurchaseService get iapService => getIt<InAppPurchaseService>();
  ProfileProvider get profileProvider => getIt<ProfileProvider>();
  PromoCodeService get promoCodeService => getIt<PromoCodeService>();

  AdService get likeAdService => getIt<AdService>(instanceName: 'like');
  AdService get scrollAdService => getIt<AdService>(instanceName: 'scroll');
  AdService get ghostAdService => getIt<AdService>(instanceName: 'ghost');

  Future<void> init() async {
    try {
      final client = supabase_pkg.Supabase.instance.client;
      getIt.registerSingleton<supabase_pkg.SupabaseClient>(client);
      getIt.registerLazySingleton<NetworkUtils>(() => NetworkUtils());
      getIt.registerLazySingleton<BatchService>(() => BatchService(client));
      getIt.registerLazySingleton<MessageCacheService>(() => MessageCacheService());
      getIt.registerLazySingleton<InAppPurchaseService>(() => InAppPurchaseService());
      getIt.registerLazySingleton<ProfileProvider>(() => ProfileProvider());
      getIt.registerLazySingleton<PromoCodeService>(() => PromoCodeService());

      getIt.registerSingleton<AdService>(AdService(), instanceName: 'like', dispose: (s) => s.dispose());
      getIt.registerSingleton<AdService>(AdService(), instanceName: 'scroll', dispose: (s) => s.dispose());
      getIt.registerSingleton<AdService>(AdService(), instanceName: 'ghost', dispose: (s) => s.dispose());

      _preloadRewardedAds();

      if (kDebugMode) {
        log('ServiceLocator initialized successfully');
      }
    } catch (e) {
      throw Exception('Failed to initialize ServiceLocator: $e');
    }
  }

  void _preloadRewardedAds() {
    likeAdService.loadRewardedAd();
    scrollAdService.loadRewardedAd();
    ghostAdService.loadRewardedAd();
    log('[Ad Pre-load] Attempting to load all rewarded ads at startup.');
  }

  static Future<void> configure() async {
    try {
      await getIt.allReady();
    } catch (e) {
      throw Exception('Failed to configure ServiceLocator: $e');
    }
  }

  Future<void> reset() async {
    try {
      await getIt.reset();
    } catch (e) {
      throw Exception('Failed to reset ServiceLocator: $e');
    }
  }
}

final serviceLocator = ServiceLocator();
// --- END: CORRECT AND COMPLETE service_locator.dart ---