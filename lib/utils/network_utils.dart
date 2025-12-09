import 'dart:async';
import 'package:http/http.dart' as http;

class NetworkUtils {
  static const int maxRetries = 3;
  static const Duration initialDelay = Duration(seconds: 1);
  static const Duration maxDelay = Duration(seconds: 10);

  static Future<http.Response> executeWithRetry(
    Future<http.Response> Function() request, {
    int maxRetries = maxRetries,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;
    
    while (true) {
      try {
        final response = await request();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }
        
        // Don't retry on client errors (4xx) except 408 (Request Timeout) and 429 (Too Many Requests)
        if (response.statusCode >= 400 && response.statusCode < 500 &&
            response.statusCode != 408 && response.statusCode != 429) {
          return response;
        }
        
        if (++attempt > maxRetries) {
          return response;
        }
      } catch (e) {
        if (++attempt > maxRetries) {
          rethrow;
        }
      }
      
      // Exponential backoff with jitter
      await Future.delayed(delay);
      final nextDelayMs = (delay.inMilliseconds * 1.5).toInt();
      delay = Duration(milliseconds: nextDelayMs > maxDelay.inMilliseconds 
          ? maxDelay.inMilliseconds 
          : nextDelayMs);
    }
  }

  static Future<T> withRetry<T>(
    Future<T> Function() fn, {
    int maxRetries = maxRetries,
    bool Function(T)? isSuccess,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;
    
    while (true) {
      try {
        final result = await fn();
        if (isSuccess == null || isSuccess(result)) {
          return result;
        }
        
        if (++attempt > maxRetries) {
          return result;
        }
      } catch (e) {
        if (++attempt > maxRetries) {
          rethrow;
        }
      }
      
      await Future.delayed(delay);
      delay = Duration(milliseconds: ((delay.inMilliseconds * 1.5).toInt()).clamp(0, maxDelay.inMilliseconds));
    }
  }
}
