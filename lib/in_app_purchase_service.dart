import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

// --- Product ID Constants ---
const String kProductIdLike1 = 'daaymn_like_1_p';
const String kProductIdLike10 = 'daaymn_like_10_p';
const String kProductIdLike20 = 'daaymn_like_20_p';
const String kProductIdReportBasic = 'daaymn_report_basic_p';
const String kProductIdReportPro = 'daaymn_report_pro_p';
const String kProductIdReportDeluxe = 'daaymn_report_deluxe_p';
const String kProductIdUnlockScrolling = 'daaymn_unlock_scrolling_d';
const String kProductIdUnlockVisibility = 'daaymn_unlock_visibility_d';
const String kProductIdSubStandard = 'daaymn_sub_standard_monthly_p';
const String kProductIdSubPro = 'daaymn_sub_pro_monthly_p';
const String kProductIdSubDeluxe = 'daaymn_sub_deluxe_monthly_p';

const Set<String> _kProductIds = <String>{
  kProductIdLike1,
  kProductIdLike10,
  kProductIdLike20,
  kProductIdReportBasic,
  kProductIdReportPro,
  kProductIdReportDeluxe,
  kProductIdUnlockScrolling,
  kProductIdUnlockVisibility,
  kProductIdSubStandard,
  kProductIdSubPro,
  kProductIdSubDeluxe,
};

// --- Private Constants for Logic ---
const String _kPrefixLike = 'daaymn_like';
const String _kPrefixReport = 'daaymn_report';
const String _kPrefixUnlock = 'daaymn_unlock';
const String _kPrefixSubscription = 'daaymn_sub';

enum _LogLevel { info, warning, error }

/// A simple logger to standardize console output for this service.
void _log(String message, {_LogLevel level = _LogLevel.info}) {
  final prefix = switch (level) {
    _LogLevel.info => '[IAP INFO]',
    _LogLevel.warning => '[IAP WARNING]',
    _LogLevel.error => '[IAP ERROR]',
  };
  // Use debugPrint which is good for Android logcat
  debugPrint('$prefix $message');
}

class InAppPurchaseService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // --- Public State ---
  bool get isStoreAvailable => _isStoreAvailable;
  List<ProductDetails> get products => _products;
  bool get isPurchasePending => _isPurchasePending;
  String? get purchaseError => _purchaseError;
  bool get purchaseCompleted => _purchaseCompleted;
  String? lastPurchasedProductId;

  // --- Private State ---
  bool _isStoreAvailable = false;
  List<ProductDetails> _products = [];
  bool _isPurchasePending = false;
  String? _purchaseError;
  bool _purchaseCompleted = false;

  void clearPurchaseCompletedFlag() {
    _log('Clearing purchase completed flag. Last purchased product was: $lastPurchasedProductId');
    _purchaseCompleted = false;
    lastPurchasedProductId = null;
    // Don't notify listeners here to avoid unnecessary UI rebuilds
  }

  InAppPurchaseService() {
    _log('Service created. Setting up purchase stream listener.');
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _handlePurchaseUpdates,
      onDone: () {
        _log('Purchase stream has been closed.');
        _subscription.cancel();
      },
      onError: (error) {
        _log('Purchase stream error: $error', level: _LogLevel.error);
        _setError('Connection to the store failed.');
      },
    );
    initialize();
  }

  @override
  void dispose() {
    _log('Service disposed. Cancelling purchase stream subscription.');
    _subscription.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    _log('Initializing...');
    _isStoreAvailable = await _iap.isAvailable();
    _log('Store available? $_isStoreAvailable');

    if (_isStoreAvailable) {
      await _loadProducts();
      _log('Attempting to restore past purchases...');
      try {
        await _iap.restorePurchases();
        _log('Finished restoring purchases.');
      } catch (e) {
          _log('Error during restorePurchases: $e', level: _LogLevel.error);
      }
    } else {
      _setError('The store is not available on this device.');
    }
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    _log('Loading product details...');
    try {
      final response = await _iap.queryProductDetails(_kProductIds);
      if (response.error != null) {
        _setError('Failed to load products: ${response.error!.message}');
        return;
      }
      _products = response.productDetails;
      _log('Loaded ${_products.length} products: ${_products.map((p) => p.id).join(', ')}');
      if (response.notFoundIDs.isNotEmpty) {
        _log('Products not found: ${response.notFoundIDs.join(', ')}', level: _LogLevel.warning);
      }
    } catch (e) {
      _setError('An unexpected error occurred while loading products: $e');
    }
  }

  Future<void> buyProduct(ProductDetails productDetails) async {
    if (_isPurchasePending) {
      _log('Purchase already pending, ignoring request for ${productDetails.id}.', level: _LogLevel.warning);
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _setError('You must be signed in to make a purchase.');
      return;
    }

    _setPending();

    final purchaseParam = PurchaseParam(
      productDetails: productDetails,
      applicationUserName: userId,
    );

    _log('Initiating purchase for ${productDetails.id} for user $userId');
    try {
      final isConsumable = productDetails.id.startsWith(_kPrefixLike) ||
          productDetails.id.startsWith(_kPrefixReport);

      if (isConsumable) {
        _log('Buying as CONSUMABLE.');
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      } else {
        _log('Buying as NON-CONSUMABLE.');
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      _setError('An error occurred while initiating the purchase: $e');
    }
  }

  Future<void> claimProduct(String productId) async {
    if (_isPurchasePending) {
      _log('Purchase already pending, ignoring claim request for $productId.', level: _LogLevel.warning);
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _setError('You must be signed in to claim an item.');
      return;
    }

    _setPending();

    _log('Initiating claim for $productId for user $userId');
    try {
      // Directly call the server to grant the item
      final response = await Supabase.instance.client.functions.invoke('grant-promo-item', body: {
        'productId': productId,
      });

      if (response.status == 200) {
        _log('Server successfully granted product: $productId. Status: ${response.status}');
        lastPurchasedProductId = productId;
        _purchaseError = null;
        _purchaseCompleted = true;
      } else {
        _log('Server returned non-200 status for product $productId: ${response.status}. Body: ${response.data}', level: _LogLevel.error);
        _setError('Server could not grant the item.');
      }
    } catch (e) {
      _setError('An error occurred while claiming the item: $e');
    }
    _isPurchasePending = false;
    notifyListeners();
  }

  // --- Purchase Update Handling ---

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    _log('Received ${purchaseDetailsList.length} purchase update(s).');
    for (final purchase in purchaseDetailsList) {
      _log('--- Handling update for ${purchase.productID} ---');
      _log('  Status: ${purchase.status}');
      _log('  Error: ${purchase.error}');
      _log('  pendingCompletePurchase: ${purchase.pendingCompletePurchase}');
      _log('  Verification Data Present: ${purchase.verificationData.serverVerificationData.isNotEmpty}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _log('  -> Status is PENDING. Setting pending state.');
          _setPending();
          break;
        case PurchaseStatus.purchased:
          _log('  -> Status is PURCHASED. Starting success flow.');
          _handleSuccessfulPurchase(purchase);
          break;
        case PurchaseStatus.restored:
          _log('  -> Status is RESTORED. This is a previously owned item.');
          // With promo codes, this might be triggered. We need to ensure we verify it.
           _log('  Starting verification flow for restored purchase.');
          _handleSuccessfulPurchase(purchase);
          break;
        case PurchaseStatus.error:
          _log('  -> Status is ERROR. Handling error.', level: _LogLevel.error);
          _handleError(purchase);
          break;
        case PurchaseStatus.canceled:
          _log('  -> Status is CANCELED. Handling cancellation.');
          _handleCanceled();
          break;
      }
      _log('--- Finished handling ${purchase.productID} ---');
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    _log('Handling successful purchase for ${purchase.productID}.');
    bool isPurchaseValid = false;
    try {
      isPurchaseValid = await _verifyAndDeliverPurchase(purchase);
    } catch (e) {
      _log('Verification process failed with exception for ${purchase.productID}: $e', level: _LogLevel.error);
      isPurchaseValid = false;
    }

    if (isPurchaseValid) {
      _log('Purchase for ${purchase.productID} was VERIFIED and DELIVERED.');
      lastPurchasedProductId = purchase.productID;
      _purchaseError = null;
      _purchaseCompleted = true;
    } else {
      _log('Purchase for ${purchase.productID} was INVALID or server delivery failed.', level: _LogLevel.warning);
      _purchaseError = 'Purchase verification or delivery failed. If the charge went through, please contact support.';

      // *** FIX FOR STUCK RESTORED PURCHASES ***
      // If a restored purchase fails verification (e.g., it's an old, expired token),
      // we must still consume it to clear it from the Google Play queue.
      if (purchase.status == PurchaseStatus.restored && defaultTargetPlatform == TargetPlatform.android) {
        _log('Attempting to consume invalid RESTORED purchase to clear queue: ${purchase.productID}', level: _LogLevel.warning);
        try {
          final InAppPurchaseAndroidPlatformAddition androidAddition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
          await androidAddition.consumePurchase(purchase);
          _log('Successfully consumed invalid restored purchase: ${purchase.productID}.');
        } catch (e) {
          _log('Failed to consume invalid restored purchase ${purchase.productID}: $e', level: _LogLevel.error);
        }
      }
    }

    if (purchase.pendingCompletePurchase) {
      _log('Completing purchase for ${purchase.productID}.');
      await _iap.completePurchase(purchase);
      _log('Purchase for ${purchase.productID} has been completed.');
    }

    _isPurchasePending = false;
    _log('Notifying listeners of purchase update.');
    notifyListeners();
  }

  void _handleCanceled() {
    _log('Purchase was canceled by the user.');
    _isPurchasePending = false;
    _purchaseError = null;
    notifyListeners();
  }

  void _handleError(PurchaseDetails purchaseDetails) {
    String errorMessage = 'An unknown store error occurred.';
    if (purchaseDetails.error != null) {
      errorMessage = 'Store error: ${purchaseDetails.error!.code} - ${purchaseDetails.error!.message} (Source: ${purchaseDetails.error!.source})';
    }
    _log('Error during purchase of ${purchaseDetails.productID}: $errorMessage', level: _LogLevel.error);
    _setError(errorMessage);
  }

  Future<bool> _verifyAndDeliverPurchase(PurchaseDetails purchase) async {
    _log('Verifying purchase on server for product: ${purchase.productID}');
    final String productId = purchase.productID;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      _log('Cannot verify purchase, user is not logged in.', level: _LogLevel.error);
      return false;
    }

    try {
      if (productId.startsWith(_kPrefixSubscription)) {
        _log('Product is a subscription. Resetting monthly report claim status for user $userId.');
        await Supabase.instance.client.from('profiles').update({
          'has_claimed_monthly_report': false,
        }).eq('id', userId);
      }

      final verificationData = purchase.verificationData.serverVerificationData;
      if (verificationData.isEmpty) {
        _log('Purchase verification data is MISSING for ${purchase.productID}. Cannot verify with server.', level: _LogLevel.error);
        throw Exception('Purchase verification data is missing.');
      }
      _log("Verification data is PRESENT. Calling Supabase function 'verify-google-purchase'.");

      final response = await Supabase.instance.client.functions.invoke('verify-google-purchase', body: {
        'productId': productId,
        'token': verificationData
      });

      if (response.status == 200) {
        _log('Server successfully processed product: $productId. Status: ${response.status}');
        return true;
      } else {
        _log('Server returned non-200 status for product $productId: ${response.status}. Body: ${response.data}', level: _LogLevel.error);
        return false;
      }

    } catch (e) {
      _log('Server-side delivery FAILED for product $productId: $e', level: _LogLevel.error);
      return false;
    }
  }

  // --- State Helper Methods ---

  void _setPending() {
    _log('Setting purchase state to PENDING.');
    _isPurchasePending = true;
    _purchaseError = null;
    notifyListeners();
  }

  void _setError(String message) {
    _log('Setting error state: "$message"');
    _purchaseError = message;
    _isPurchasePending = false;
    notifyListeners();
  }
}
