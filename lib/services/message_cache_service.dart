import 'package:shared_preferences/shared_preferences.dart';

// A simple service to cache and retrieve decrypted message content locally.
class MessageCacheService {
  static const _cachePrefix = 'msg_cache_';

  // Caches the decrypted content of a message.
  Future<void> cacheMessage(String messageId, String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$messageId', content);
    } catch (e) {
      // Silently fail, caching is a non-critical enhancement.
    }
  }

  // Retrieves a cached message content.
  Future<String?> getCachedMessage(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_cachePrefix$messageId');
    } catch (e) {
      return null;
    }
  }

  // Removes a message from the cache.
  Future<void> removeMessage(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$messageId');
    } catch (e) {
       // Silently fail.
    }
  }
}
