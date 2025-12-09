import 'package:daaymn/globals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtmService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// FIX: Sends an OTM and returns the created message object.
  Future<Message> sendOtm({
    required String receiverId,
    required String encryptedContent,
  }) async {
    final response = await _supabase.from('messages').insert({
      'sender_id': _supabase.auth.currentUser!.id,
      'receiver_id': receiverId,
      'content': encryptedContent,
      'is_otm': true, // Mark this message as a One-Time Message
      'message_type': 'text',
    }).select(); // This ensures the created row is returned.
    
    // Parse and return the created message.
    return Message.fromJson(response[0]);
  }

  /// NEW LOGIC: Fetches received OTMs by querying the 'messages' table for any
  /// messages where 'is_otm' is true.
  Future<List<Message>> getReceivedOtms() async {
    final currentUserId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('messages')
        .select()
        .eq('receiver_id', currentUserId)
        .eq('is_otm', true); // Filter for OTMs

    return (response as List)
        .map((data) => Message.fromJson(data))
        .toList();
  }

  /// NEW LOGIC: Accepts an OTM.
  /// 1. Creates a 'like' to establish a match.
  /// 2. Updates the message in-place, setting 'is_otm' to false to make it a normal message.
  Future<void> acceptOtm(Message otm) async {
    // 1. Create the like to form a match
    await _supabase.from('likes').insert({
      'user_id': _supabase.auth.currentUser!.id,
      'liked_user_id': otm.senderId,
    });

    // 2. Convert the OTM into a regular message
    await _supabase
        .from('messages')
        .update({'is_otm': false})
        .match({'id': otm.id});
  }

  /// REVISED LOGIC: Rejects an OTM by only deleting the message. This allows the sender to try again.
  Future<void> rejectOtm(Message otm) async {
    // By only deleting the message, we don't create a "dislike" record.
    // This allows the persistent sender to send another OTM later.
    await _supabase.from('messages').delete().match({'id': otm.id});
  }
}
