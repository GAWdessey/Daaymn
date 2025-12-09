
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LikeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // This function now manages the entire like cooldown and granting process.
  Future<void> grantDailyLike() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profileResponse = await _supabase
          .from('profiles')
          .select('like_count, last_like_granted_at')
          .eq('id', userId)
          .single();

      final currentLikes = profileResponse['like_count'] as int;
      final lastGrantedString = profileResponse['last_like_granted_at'] as String?;
      final nowUtc = DateTime.now().toUtc();

      // Condition 1: User is below the max like count but has no timer running.
      // This happens when they first drop below 6 likes. We start the timer for them.
      if (currentLikes < 6 && lastGrantedString == null) {
        await _supabase.from('profiles').update({
          'last_like_granted_at': nowUtc.toIso8601String(),
        }).eq('id', userId);
        return; // Timer is started, nothing else to do for now.
      }
      
      // Condition 2: A timer is running or has finished.
      if (lastGrantedString != null) {
        final lastGrantedUtc = DateTime.parse(lastGrantedString);

        // Don't grant a like if they are already at the max.
        if (currentLikes >= 6) {
          return;
        }

        // Check if 20 hours have passed to grant a new like.
        if (nowUtc.difference(lastGrantedUtc).inHours >= 20) {
          await _supabase.from('profiles').update({
            'like_count': currentLikes + 1,
            'last_like_granted_at': nowUtc.toIso8601String(), // Reset the timer for the next like
          }).eq('id', userId);
        }
      }

    } catch (e) {
      // Handle error, maybe log it
      debugPrint('Error in like management service: $e');
    }
  }
}
