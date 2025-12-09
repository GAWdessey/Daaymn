import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PromoCodeService extends ChangeNotifier {
  String? _redeemedProductId;
  bool _isRedeeming = false;
  String? _error;

  String? get redeemedProductId => _redeemedProductId;
  bool get isRedeeming => _isRedeeming;
  String? get error => _error;

  Future<bool> redeemCode(String code) async {
    if (isRedeeming) return false;

    _isRedeeming = true;
    _error = null;
    notifyListeners();

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'redeem-promo-code',
        body: {'code': code},
      );

      if (response.status == 200) {
        _redeemedProductId = response.data['productId'];
        _isRedeeming = false;
        notifyListeners();
        return true;
      } else {
        _error = response.data['error'] ?? 'An unknown error occurred.';
        _isRedeeming = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'An unexpected error occurred.';
      _isRedeeming = false;
      notifyListeners();
      return false;
    }
  }

  void clearRedeemedProduct() {
    _redeemedProductId = null;
    notifyListeners();
  }
}
