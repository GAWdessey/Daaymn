import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class BatchService {
  final SupabaseClient _supabase;
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  final Map<String, Completer<List<Map<String, dynamic>>>> _pendingRequests = {};

  BatchService(this._supabase);

  /// Fetches data with automatic batching and caching
  Future<List<Map<String, dynamic>>> fetchData({
    required String table,
    Map<String, dynamic>? filters,
    String? query,
    int page = 0,
    int pageSize = 20,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    final key = _generateKey(
      table: table,
      filters: filters,
      query: query,
      page: page,
      pageSize: pageSize,
      orderBy: orderBy,
      ascending: ascending,
    );

    // Return from cache if available
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    // If request is already in progress, return the existing future
    if (_pendingRequests.containsKey(key)) {
      return _pendingRequests[key]!.future;
    }

    final completer = Completer<List<Map<String, dynamic>>>();
    _pendingRequests[key] = completer;

    try {
      var queryBuilder = _supabase.from(table).select();

// Apply filters
      if (filters != null && filters.isNotEmpty) {
        for (final entry in filters.entries) {
          if (entry.value != null) {
            if (entry.value is List) {
              queryBuilder = queryBuilder.inFilter(entry.key, entry.value as List);
            } else {
              queryBuilder = queryBuilder.eq(entry.key, entry.value);
            }
          }
        }
      }

// Execute the query with ordering and pagination — DO NOT assign back
      final response = await queryBuilder
          .order(orderBy, ascending: ascending)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      final result = List<Map<String, dynamic>>.from(response);

// Cache and complete
      _cache[key] = result;
      completer.complete(result);
      _pendingRequests.remove(key);

      return result;
    } catch (e) {
      completer.completeError(e);
      _pendingRequests.remove(key);
      rethrow;
    }
  }

  /// Creates a real-time stream of data from the specified table
  Stream<List<Map<String, dynamic>>> streamData({
    required String table,
    Map<String, dynamic>? filters,
    String orderBy = 'created_at',
    bool ascending = false,
    int pageSize = 20,
  }) {
    final key = _generateStreamKey(
      table: table,
      filters: filters,
      orderBy: orderBy,
      ascending: ascending,
      pageSize: pageSize,
    );

    // Return existing stream if available
    if (_subscriptions.containsKey(key)) {
      return _getCachedStream(key);
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    try {
      var query = _supabase.from(table).select();

// Apply filters
      if (filters != null && filters.isNotEmpty) {
        for (final entry in filters.entries) {
          if (entry.value != null) {
            if (entry.value is List) {
              query = query.inFilter(entry.key, entry.value as List);
            } else {
              query = query.eq(entry.key, entry.value);
            }
          }
        }
      }

// Apply ordering and limit — chain directly
      query.order(orderBy, ascending: ascending).limit(pageSize);

// Create the stream
      final stream = query.asStream();


      // Listen to the stream
      final subscription = stream.listen(
        (data) {
          final result = List<Map<String, dynamic>>.from(data);
          _cache[key] = result;
          controller.add(result);
        },
        onError: (error) {
          controller.addError('Stream error: $error');
        },
        cancelOnError: false,
      );

      _subscriptions[key] = subscription;
      return controller.stream;
    } catch (e) {
      controller.addError('Failed to create stream: $e');
      return controller.stream;
    }
  }

  /// Generates a unique key for a request
  String _generateKey({
    required String table,
    Map<String, dynamic>? filters,
    String? query,
    required int page,
    required int pageSize,
    String orderBy = 'created_at',
    bool ascending = false,
  }) {
    final filterString = filters?.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',');
    
    return '$table|${query ?? 'null'}|${filterString ?? 'null'}|$page|$pageSize|$orderBy|$ascending';
  }

  /// Generates a unique key for a stream
  String _generateStreamKey({
    required String table,
    Map<String, dynamic>? filters,
    required String orderBy,
    required bool ascending,
    required int pageSize,
  }) {
    final filterString = filters?.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',');
    
    return 'stream|$table|${filterString ?? 'null'}|$orderBy|$ascending|$pageSize';
  }

  /// Gets a cached stream or creates a new one
  Stream<List<Map<String, dynamic>>> _getCachedStream(String key) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    
    // Send cached data immediately if available
    if (_cache.containsKey(key)) {
      controller.add(_cache[key]!);
    } else {
      controller.add([]);
    }
    
    return controller.stream;
  }

  /// Disposes all resources
  void dispose() {
    // Cancel all active subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    // Complete any pending requests with an error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('BatchService was disposed'));
      }
    }
    _pendingRequests.clear();
    
    // Clear cache
    _cache.clear();
  }
}
