
import 'dart:convert';
import 'package:daaymn/chat_screen.dart';
import 'package:daaymn/globals.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class PushNotificationService with WidgetsBindingObserver {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // --- Topic Names ---
  static const String matchesTopic = 'new_matches';
  static const String likesTopic = 'new_likes';
  static const String messagesTopic = 'new_messages';

  PushNotificationService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<bool> requestNotificationPermission() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  Future<void> init() async {
    if (_initialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('ic_notification1');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            _handleNotificationTap(response.payload!);
          }
        },
      );

      final NotificationAppLaunchDetails? notificationAppLaunchDetails =
          await _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
      if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
        final payload = notificationAppLaunchDetails!.notificationResponse?.payload;
        if (payload != null) {
          Future.delayed(const Duration(seconds: 1), () {
            _handleNotificationTap(payload);
          });
        }
      }

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications like new likes and matches.',
        importance: Importance.max,
        playSound: true,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(jsonEncode(message.toMap()));
      });

    } catch (e) {
      debugPrint('Error initializing push notifications: $e');
    } finally {
      _initialized = true;
    }
  }

  Future<void> getAndStoreFCMToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _storeFCMToken(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _storeFCMToken(String token) async {
    try {
      final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await supabase.Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
      }
    } catch (e) {
      debugPrint('Error storing FCM token: $e');
    }
  }

   // --- Topic Subscription Methods ---
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }

  Future<void> _handleNotificationTap(String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final notificationType = data['data']?['type'] as String?;
      final senderId = data['data']?['sender_id'] as String?;

      if (senderId != null) {
        final currentUserId = supabase.Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId == null) return;

        final blockedResponse = await supabase.Supabase.instance.client
            .from('blocks')
            .select('id')
            .or('blocker_id.eq.$currentUserId,blocked_id.eq.$senderId')
            .or('blocker_id.eq.$senderId,blocked_id.eq.$currentUserId');

        if (blockedResponse.isNotEmpty) {
          return; // Don't handle notification if there is a block
        }
      }

      switch (notificationType) {
        case 'new_match':
          navigatorKey.currentState?.pushNamed('/matches');
          break;
        case 'otm':
          final senderProfileData = jsonDecode(data['data']['sender_profile']);
          final messageData = jsonDecode(data['data']['message']);
          final senderProfile = Profile.fromJson(senderProfileData);
          final message = Message.fromJson(messageData);

          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (context) => ChatScreen(
              otherUser: senderProfile,
              initialMessage: message,
              isOtm: true,
            ),
          ));
          break;
        case 'new_message':
          final chatId = data['data']?['chat_id'];
          if (chatId != null) {
            navigatorKey.currentState?.pushNamed('/chat/$chatId');
          }
          break;
        case 'new_like':
          navigatorKey.currentState?.pushNamed('/likes');
          break;
        default:
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
