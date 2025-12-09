import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:daaymn/services/batch_service.dart';
import 'package:daaymn/services/service_locator.dart';
import 'package:daaymn/utils/network_utils.dart';

class ApiUtils {
  final SupabaseClient _supabase;
  final BatchService _batchService;

  ApiUtils(this._supabase, this._batchService);

  /// Generic method to execute a query with retry logic
  Future<List<Map<String, dynamic>>> executeQuery({
    required String table,
    String? query,
    Map<String, dynamic>? filters,
    int page = 0,
    int pageSize = 10,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      var queryBuilder = _supabase.from(table).select();

      // Apply filters (for normal PostgREST queries)
      if (filters != null && filters.isNotEmpty) {
        filters.forEach((key, value) {
          if (value != null) {
            queryBuilder = queryBuilder.filter(key, 'eq', value);
          }
        });
      }

      final response = await queryBuilder
          .order(orderBy, ascending: ascending)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Retry using network utils
      return await NetworkUtils.withRetry(
            () => executeQuery(
          table: table,
          query: query,
          filters: filters,
          page: page,
          pageSize: pageSize,
          orderBy: orderBy,
          ascending: ascending,
        ),
      );
    }
  }

  /// Stream batched data with real-time updates
  Stream<List<Map<String, dynamic>>> streamBatchedData({
    required String table,
    Map<String, dynamic>? filters,
    String orderBy = 'created_at',
    bool ascending = false,
    int pageSize = 20,
  }) {
    try {
      // Create the base query
      var query = _supabase.from(table).select();
      
      // Apply filters if any
      if (filters != null && filters.isNotEmpty) {
        filters.forEach((key, value) {
          if (value != null) {
            if (value is List) {
              query = query.inFilter(key, value);
            } else {
              query = query.eq(key, value);
            }
          }
        });
      }
      
      // Apply ordering and limit
      final orderedQuery = query.order(orderBy, ascending: ascending);
      final limitedQuery = orderedQuery.limit(pageSize);
      
      // Create the stream
      return limitedQuery.asStream().handleError((error) {
        debugPrint('Stream error for table $table: $error');
      });
    } catch (e) {
      debugPrint('Error creating stream for $table: $e');
      return const Stream.empty();
    }
  }

  /// Fetch batched data
  Future<List<Map<String, dynamic>>> fetchBatchedData({
    required String table,
    String? query,
    Map<String, dynamic>? filters,
    int page = 0,
    int pageSize = 10,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      return await _batchService.fetchData(
        table: table,
        query: query,
        filters: filters,
        page: page,
        pageSize: pageSize,
        orderBy: orderBy,
        ascending: ascending,
      );
    } catch (e) {
      return await executeQuery(
        table: table,
        query: query,
        filters: filters,
        page: page,
        pageSize: pageSize,
        orderBy: orderBy,
        ascending: ascending,
      );
    }
  }

  /// Real-time subscription for user's matches
  Stream<List<Map<String, dynamic>>> subscribeToUserMatches(String userId) {
    return _supabase
        .from('matches')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .asStream()
        .handleError((error) {
          debugPrint('Matches subscription error: $error');
        });
  }

  /// Real-time subscription for chat messages
  Stream<List<Map<String, dynamic>>> subscribeToChat(String chatId) {
    return _supabase
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at')
        .asStream()
        .handleError((error) {
          debugPrint('Chat subscription error: $error');
        });
  }

  /// Real-time subscription for new likes
  Stream<List<Map<String, dynamic>>> subscribeToNewLikes(String userId) {
    return _supabase
        .from('likes')
        .select()
        .eq('target_user_id', userId)
        .eq('is_seen', false)
        .order('created_at', ascending: false)
        .asStream()
        .handleError((error) {
          debugPrint('New likes subscription error: $error');
        });
  }

  /// Real-time subscription for user's profile updates
  Stream<Map<String, dynamic>?> subscribeToUserProfile(String userId) {
    return _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .limit(1)
        .asStream()
        .map((list) => list.isNotEmpty ? list.first : null)
        .handleError((error) {
          debugPrint('Profile subscription error: $error');
        });
  }

  /// Handle network errors
  static String handleNetworkError(dynamic error) {
    if (error is PostgrestException) {
      return _handlePostgrestError(error);
    } else if (error.toString().contains('Connection closed before full header was received')) {
      return 'Connection lost. Please check your internet connection and try again.';
    } else if (error.toString().contains('Connection reset by peer')) {
      return 'Connection reset. Please try again.';
    } else if (error is TimeoutException || error.toString().contains('TimeoutException')) {
      return 'Request timed out. Please check your internet connection.';
    } else {
      return 'An error occurred. Please try again later.';
    }
  }

  /// Handle PostgREST-specific errors
  static String _handlePostgrestError(PostgrestException e) {
    if (e.code == 'PGRST301' || e.code == 'PGRST302') {
      return 'Invalid request format or parameters.';
    }
    return e.message;
  }

  /// Show error dialog
  static void showErrorDialog(BuildContext context, dynamic error) {
    final errorMessage = handleNetworkError(error);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Global instance
final apiUtils = ApiUtils(serviceLocator.supabaseClient, serviceLocator.batchService);
