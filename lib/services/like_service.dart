import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LikeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // The cooldown and cap are enforced by the request_daily_like RPC; the
  // client can't write like_count itself.
  Future<void> grantDailyLike() async {
    if (_supabase.auth.currentUser == null) return;

    try {
      await _supabase.rpc('request_daily_like');
    } catch (e) {
      debugPrint('Error in like management service: $e');
    }
  }
}
