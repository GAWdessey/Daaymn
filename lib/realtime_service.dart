import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  final SupabaseClient _supabase;
  
  final _controller = StreamController<void>.broadcast();
  Stream<void> get stream => _controller.stream;

  RealtimeService(this._supabase) {
    _initializeListeners();
  }

  void _initializeListeners() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    void listener(payload) {
      if (!_controller.isClosed) {
        _controller.add(null); // Just notify that something changed
      }
    }

    // A single channel for all relevant events
    _supabase
        .channel('public:likes,dislikes,blocks')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'likes', callback: listener)
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'dislikes', callback: listener)
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'blocks', callback: listener)
        .subscribe();
  }

  void dispose() {
    _controller.close();
  }
}
