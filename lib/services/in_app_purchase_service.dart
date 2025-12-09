
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
  kProductIdLike1, kProductIdLike10, kProductIdLike20,
  kProductIdReportBasic, kProductIdReportPro, kProductIdReportDeluxe,
  kProductIdUnlockScrolling, kProductIdUnlockVisibility,
  kProductIdSubStandard, kProductIdSubPro, kProductIdSubDeluxe,
};

enum _LogLevel { info, warning, error }

void _log(String message, {_LogLevel level = _LogLevel.info}) {
  final prefix = '[IAP ${level.name.toUpperCase()}]';
  debugPrint('$prefix: $message');
}

class InAppPurchaseService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isStoreAvailable = false;
  List<ProductDetails> _products = [];
  bool _isPurchasePending = false;
  String? _purchaseError;
  bool _purchaseCompleted = false;
  String? lastPurchasedProductId; // Field for UI to know which product was redeemed

  bool get isStoreAvailable => _isStoreAvailable;
  List<ProductDetails> get products => _products;
  bool get isPurchasePending => _isPurchasePending;
  String? get purchaseError => _purchaseError;
  bool get purchaseCompleted => _purchaseCompleted;

  InAppPurchaseService() {
    _log('Service created. Setting up purchase stream listener.');
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _handlePurchaseUpdates,
      onDone: () {
        _log('Purchase stream has been closed.');
        _subscription.cancel();
      },
      onError: (e) {
        _log('Purchase stream error: $e', level: _LogLevel.error);
        _setError('Store connection failed.');
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

  void clearPurchaseCompletedFlag() {
    _log('Clearing purchase completed flag. Last product: $lastPurchasedProductId');
    _purchaseCompleted = false;
    lastPurchasedProductId = null;
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
  }

  Future<void> _loadProducts() async {
    _log('Loading product details for IDs: $_kProductIds');
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
    notifyListeners();
  }

  Future<void> buyProduct(ProductDetails productDetails) async {
    if (_isPurchasePending) {
      _log('Purchase already pending, ignoring request.', level: _LogLevel.warning);
      return;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _setError('You must be signed in to make a purchase.');
      return;
    }

    _setPending(true);
    _log('Initiating purchase for ${productDetails.id} for user $userId');

    final purchaseParam = PurchaseParam(
      productDetails: productDetails,
      applicationUserName: userId,
    );
    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _log('Error initiating purchase: $e', level: _LogLevel.error);
      _setError('An error occurred while starting the purchase.');
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> detailsList) {
    _log('Received ${detailsList.length} purchase update(s).');
    for (final details in detailsList) {
      _log('--- Handling update for ${details.productID} ---');
      _log('  Status: ${details.status}');
      _log('  Error: ${details.error}');
      _log('  pendingCompletePurchase: ${details.pendingCompletePurchase}');
      _log('  Verification Data Present: ${details.verificationData.serverVerificationData.isNotEmpty}');
      switch (details.status) {
        case PurchaseStatus.pending:
          _log('  -> Status is PENDING. Setting pending state.');
          _setPending(true);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored: // Treat restored same as purchased for verification
          _log('  -> Status is ${details.status}. Starting success flow.');
          _processNewPurchase(details);
          break;
        case PurchaseStatus.error:
          _log('  -> Status is ERROR. Handling error.', level: _LogLevel.error);
          _handleError(details.error?.message ?? 'An unknown error occurred.');
          break;
        case PurchaseStatus.canceled:
          _log('  -> Status is CANCELED. Setting pending to false.');
          _setPending(false);
          break;
      }
      _log('--- Finished handling ${details.productID} ---');
    }
  }

  Future<void> _processNewPurchase(PurchaseDetails details) async {
    _log('Processing new/restored purchase for ${details.productID}');
    final isValid = await _verifyWithServer(details);

    if (isValid) {
      _log('Purchase for ${details.productID} was VERIFIED.');
      _purchaseCompleted = true;
      lastPurchasedProductId = details.productID; // Set this for the UI
    } else {
      _log('Purchase for ${details.productID} was INVALID.', level: _LogLevel.error);
      _setError('Purchase verification failed. Please contact support.');
    }

    if (details.pendingCompletePurchase) {
      _log('Completing purchase for ${details.productID}');
      await _iap.completePurchase(details);
      _log('Purchase for ${details.productID} completed.');
    }
    _setPending(false);
  }

  Future<bool> _verifyWithServer(PurchaseDetails details) async {
    _log('Verifying purchase on server for product: ${details.productID}');
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-google-purchase',
        body: {
          'productId': details.productID,
          'token': details.verificationData.serverVerificationData,
        },
      );
      if (response.status != 200) {
        _log('Server verification failed with status ${response.status}. Data: ${response.data}', level: _LogLevel.error);
        return false;
      }
      _log('Server verification successful for ${details.productID}');
      return true;
    } catch (e) {
      _log('Server verification failed with exception: $e', level: _LogLevel.error);
      return false;
    }
  }

  void _handleError(String message) {
    _setError(message);
  }

  void _setPending(bool isPending) {
    _isPurchasePending = isPending;
    if (!isPending) _purchaseError = null;
    notifyListeners();
  }

  void _setError(String message) {
    _purchaseError = message;
    _isPurchasePending = false;
    _log(message, level: _LogLevel.error);
    notifyListeners();
  }
}
