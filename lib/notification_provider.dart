import 'dart:async';
import 'package:daaymn/cryptography_service.dart';
import 'package:daaymn/globals.dart';
import 'package:daaymn/otm.dart';
import 'package:daaymn/services/message_cache_service.dart';
import 'package:daaymn/services/service_locator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationProvider extends ChangeNotifier {
  int _yourLikesCount = 0;
  int _likedYouCount = 0;
  int _messagesCount = 0;
  bool _isRefreshing = false; // Add this lock

  int get yourLikesCount => _yourLikesCount;
  int get likedYouCount => _likedYouCount;
  int get messagesCount => _messagesCount;
  int get totalCount => _yourLikesCount + _likedYouCount + _messagesCount;

  RealtimeChannel? _yourLikesChannel;
  RealtimeChannel? _likedYouChannel;
  RealtimeChannel? _messagesChannel;

  void initialize() {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    disposeChannels();

    void callback(payload) {
      if (!_isRefreshing) { // Check the lock before refreshing
        refresh();
      }
    }

    _yourLikesChannel = supabase.channel('your_likes_count');
    _yourLikesChannel?.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'likes',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: currentUserId),
      callback: callback,
    ).subscribe();

    _likedYouChannel = supabase.channel('liked_you_count');
    _likedYouChannel?.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'likes',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'liked_user_id', value: currentUserId),
      callback: callback,
    ).subscribe();

    _messagesChannel = supabase.channel('messages_count');
    _messagesChannel?.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'receiver_id', value: currentUserId),
      callback: callback,
    ).subscribe();
    
    refresh();
  }

  Future<void> refresh() async {
    if (_isRefreshing) return; // Prevent concurrent refreshes
    _isRefreshing = true;

    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      _isRefreshing = false;
      return;
    }

    try {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();

      final responses = await Future.wait([
        supabase.from('blocks').select('blocked_id').eq('blocker_id', currentUserId),
        supabase.from('blocks').select('blocker_id').eq('blocked_id', currentUserId),
        supabase.from('likes').select('liked_user_id').eq('user_id', currentUserId).gte('created_at', threeDaysAgo),
        supabase.from('likes').select('user_id').eq('liked_user_id', currentUserId),
        supabase.from('dislikes').select('disliked_user_id').eq('user_id', currentUserId),
        supabase.from('messages').count().eq('receiver_id', currentUserId).eq('is_read', false).eq('is_otm', false),
        supabase.from('messages').count().eq('receiver_id', currentUserId).eq('is_read', false).eq('is_otm', true),
      ]);

      final iHaveBlocked = (responses[0] as List).map((e) => e['blocked_id'].toString()).toSet();
      final whoBlockedMe = (responses[1] as List).map((e) => e['blocker_id'].toString()).toSet();
      final allBlockedUsers = iHaveBlocked.union(whoBlockedMe);

      final myLikes = (responses[2] as List).map((e) => e['liked_user_id'].toString()).toSet();
      final whoLikedMe = (responses[3] as List).map((e) => e['user_id'].toString()).toSet();
      final myDislikes = (responses[4] as List).map((e) => e['disliked_user_id'].toString()).toSet();
      
      final unreadMessagesCount = responses[5] as int;
      final unreadOtmsCount = responses[6] as int;

      final matches = myLikes.intersection(whoLikedMe);

      _yourLikesCount = myLikes.difference(matches).difference(allBlockedUsers).length;
      _likedYouCount = whoLikedMe.difference(matches).difference(myDislikes).difference(allBlockedUsers).length;
      _messagesCount = unreadMessagesCount + unreadOtmsCount; 

    } catch (e) {
      debugPrint("Error refreshing notification counts: $e");
       _yourLikesCount = 0;
       _likedYouCount = 0;
       _messagesCount = 0;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }


  void markYourLikesAsSeen() {
    if (_yourLikesCount == 0) return;
    _yourLikesCount = 0;
    notifyListeners();
  }
  
  void markLikedYouAsSeen() {
    if (_likedYouCount == 0) return;
    _likedYouCount = 0;
    notifyListeners();
  }

  void markMessagesAsSeen() {
    if (_messagesCount == 0) return;
    _messagesCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    disposeChannels();
    super.dispose();
  }

  void disposeChannels() {
    _yourLikesChannel?.unsubscribe();
    _likedYouChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
  }
}

class Conversation {
  final Profile otherUser;
  final Message? lastMessage;
  final int unreadCount;
  final bool isMatch;
  final bool isOtm;

  Conversation({
    required this.otherUser,
    this.lastMessage,
    required this.unreadCount,
    required this.isMatch,
    required this.isOtm,
  });

  Conversation copyWith({Profile? otherUser, Message? lastMessage, int? unreadCount, bool? isMatch, bool? isOtm}) {
    return Conversation(
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isMatch: isMatch ?? this.isMatch,
      isOtm: isOtm ?? this.isOtm,
    );
  }
}

class MessageProvider extends ChangeNotifier {
  List<Conversation> _matchedConversations = [];
  List<Conversation> _oneTimeConversations = [];
  bool _isLoading = true;
  String? _errorMessage;

  RealtimeChannel? _profileSubscription;

  final CryptographyService _cryptographyService = CryptographyService();
  final MessageCacheService _messageCache = serviceLocator.messageCache;
  final OtmService _otmService = OtmService();
  pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>? _myKeyPair;
  bool _keysLoaded = false;

  List<Conversation> get matchedConversations => _matchedConversations;
  List<Conversation> get oneTimeConversations => _oneTimeConversations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  MessageProvider() {
    _setupKeysAndFetchData();
  }

  @override
  void dispose() {
    _profileSubscription?.unsubscribe();
    super.dispose();
  }

  void subscribeToProfileChanges() {
    _profileSubscription?.unsubscribe();
    _profileSubscription = supabase.channel('public:profiles:messages').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      callback: (payload) {
        if (payload.newRecord.isNotEmpty) {
          final updatedProfile = Profile.fromJson(payload.newRecord);
          _updateConversation(updatedProfile);
        }
      },
    ).subscribe();
  }

  void _updateConversation(Profile updatedProfile) {
    bool changed = false;
    _matchedConversations = _matchedConversations.map((c) {
      if (c.otherUser.id == updatedProfile.id) {
        changed = true;
        return c.copyWith(otherUser: updatedProfile);
      }
      return c;
    }).toList();

    _oneTimeConversations = _oneTimeConversations.map((c) {
      if (c.otherUser.id == updatedProfile.id) {
        changed = true;
        return c.copyWith(otherUser: updatedProfile);
      }
      return c;
    }).toList();

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> _setupKeysAndFetchData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = supabase.auth.currentUser!.id;
      final myKeyPair = await _cryptographyService.getOrCreateKeyPair(userId);

      _myKeyPair = myKeyPair;
      _keysLoaded = true;

      await fetchConversations();
    } catch (e) {
      _errorMessage = "An error occurred while setting up your secure session: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Message> _decryptMessage(Message message) async {
    final cachedContent = await _messageCache.getCachedMessage(message.id.toString());
    if (cachedContent != null) {
      return message.copyWith(content: cachedContent);
    }
    
    try {
      final decryptedContent = _cryptographyService.decryptString(message.content, _myKeyPair!.privateKey);
      if (decryptedContent != null) {
        await _messageCache.cacheMessage(message.id.toString(), decryptedContent);
        return message.copyWith(content: decryptedContent);
      }
    } catch (e) {
      debugPrint("Decryption failed for message ${message.id.toString()}: $e");
    }
    
    return message.copyWith(content: "[Message Encrypted]");
  }

  Future<void> fetchConversations() async {
    if (!_keysLoaded) return;

    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final responses = await Future.wait<dynamic>([
        supabase.from('blocks').select('blocked_id').eq('blocker_id', currentUserId),
        supabase.from('blocks').select('blocker_id').eq('blocked_id', currentUserId),
        supabase.from('likes').select('liked_user_id').eq('user_id', currentUserId),
        supabase.from('likes').select('user_id').eq('liked_user_id', currentUserId),
        supabase.from('messages').select().or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId').order('created_at', ascending: false),
        _otmService.getReceivedOtms(),
      ]);

      final iHaveBlocked = (responses[0] as List).map((e) => e['blocked_id'].toString()).toSet();
      final whoBlockedMe = (responses[1] as List).map((e) => e['blocker_id'].toString()).toSet();
      final allBlockedUsers = iHaveBlocked.union(whoBlockedMe);

      final myLikedIds = (responses[2] as List).map((e) => e['liked_user_id'].toString()).toSet();
      final otherLikedIds = (responses[3] as List).map((e) => e['user_id'].toString()).toSet();
      final allMessages = (responses[4] as List).map((data) => Message.fromJson(data)).toList();
      final allOtms = responses[5] as List<Message>;

      final Set<String> allRelevantUserIds = {};
      allRelevantUserIds.addAll(myLikedIds);
      allRelevantUserIds.addAll(otherLikedIds);
      for (final msg in allMessages) {
        allRelevantUserIds.add(msg.senderId == currentUserId ? msg.receiverId : msg.senderId);
      }
      for (final otm in allOtms) {
        allRelevantUserIds.add(otm.senderId);
      }

      allRelevantUserIds.removeAll(allBlockedUsers);

      if (allRelevantUserIds.isEmpty) {
        _oneTimeConversations = [];
        _matchedConversations = [];
        notifyListeners();
        return;
      }

      final profilesResponse = await supabase.from('profiles').select().inFilter('id', allRelevantUserIds.toList());

      final otherUsers = profilesResponse.map((data) => Profile.fromJson(data)).toList();

      final List<Conversation> tempMatched = [];
      final List<Conversation> tempOneTime = [];

      for (final user in otherUsers) {
        final isMatch = myLikedIds.contains(user.id) && otherLikedIds.contains(user.id);

        if (isMatch) {
          final relevantMessages = allMessages.where((m) => m.senderId == user.id || m.receiverId == user.id).toList();
          final unreadCount = relevantMessages.where((m) => m.receiverId == currentUserId && !m.isRead).length;
          Message? lastMessage = relevantMessages.isNotEmpty ? relevantMessages.first : null;

          if (lastMessage != null && lastMessage.senderId != currentUserId) {
            lastMessage = await _decryptMessage(lastMessage);
          }
          tempMatched.add(Conversation(otherUser: user, lastMessage: lastMessage, unreadCount: unreadCount, isMatch: true, isOtm: false));
        }
      }

      for (final otm in allOtms) {
        try {
          if(allBlockedUsers.contains(otm.senderId)) continue;
          final user = otherUsers.firstWhere((u) => u.id == otm.senderId);
          if (!tempMatched.any((c) => c.otherUser.id == user.id)) {
            final decryptedOtm = await _decryptMessage(otm);
            tempOneTime.add(Conversation(
              otherUser: user,
              lastMessage: decryptedOtm,
              unreadCount: 1,
              isMatch: false,
              isOtm: true,
            ));
          }
        } catch (e) {
          debugPrint('[DEBUG MESSAGE PROVIDER] Error processing OTM: $e');
        }
      }
      
      tempMatched.sort((a, b) => (b.lastMessage?.createdAt ?? DateTime(0)).compareTo(a.lastMessage?.createdAt ?? DateTime(0)));
      tempOneTime.sort((a, b) => (b.lastMessage?.createdAt ?? DateTime(0)).compareTo(a.lastMessage?.createdAt ?? DateTime(0)));

      _matchedConversations = tempMatched;
      _oneTimeConversations = tempOneTime;
    } catch (e) {
      _errorMessage = 'Failed to load messages: ${e.toString()}';
    } finally {
      notifyListeners();
    }
  }
}
