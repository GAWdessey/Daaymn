
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize services for the background isolate.
  await _initializeBackgroundServices();

  // --- Step 1: Check block list FIRST ---
  final prefs = await SharedPreferences.getInstance();
  final blockedUsers = prefs.getStringList('blocked_users') ?? [];
  final senderId = message.data['sender_id'] as String?;

  if (senderId != null && blockedUsers.contains(senderId)) {
    if (kDebugMode) {
      print('Daaymn BG: Notification from blocked user $senderId. Discarding.');
    }
    return; // Blocked user. We SILENTLY discard the message. The function stops here.
  }

  // --- Step 2: If not blocked, construct and display a local notification from DATA. ---
  final title = message.data['title'] as String?;
  final body = message.data['body'] as String?;

  if (title != null && body != null) {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // The channel should be created on app startup, but calling it here is safe and idempotent.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications like new likes and matches.',
      importance: Importance.max,
      playSound: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    // Display the notification.
    flutterLocalNotificationsPlugin.show(
      message.hashCode, // Use a unique ID for the message
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: 'ic_notification1', // IMPORTANT: Ensure this icon exists in android/app/src/main/res/drawable
        ),
      ),
      payload: jsonEncode(message.toMap()), // Pass the full message data
    );

    if (kDebugMode) {
      print('Daaymn BG: Displaying background notification: $title');
    }
  }
}

// This function mirrors the initialization logic from main.dart but for the background isolate.
Future<void> _initializeBackgroundServices() async {
  try {
    await dotenv.load(fileName: ".env");
    await Firebase.initializeApp();
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  } catch (e) {
    if (kDebugMode) {
      print('Daaymn BG: A generic error occurred during initialization: $e');
    }
  }
}
