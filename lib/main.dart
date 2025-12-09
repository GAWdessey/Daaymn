import 'package:daaymn/services/in_app_update_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:daaymn/buy_likes_screen.dart';
import 'package:daaymn/daaymn_dialog.dart';
import 'package:daaymn/display_settings_page.dart';
import 'package:daaymn/create_profile_screen.dart';
import 'package:daaymn/notification_provider.dart';
import 'package:daaymn/push_notification_service.dart';
import 'package:daaymn/services/like_service.dart';
import 'package:daaymn/theme_provider.dart';
import 'package:daaymn/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_pkg;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:daaymn/cryptography_service.dart' as crypto_service;
import 'firebase_messaging_background.dart';
import 'package:daaymn/realtime_service.dart';

// App screens
import 'package:daaymn/auth_screen.dart';
import 'package:daaymn/permissions_screen.dart';
import 'package:daaymn/services/service_locator.dart';
import 'package:daaymn/globals.dart';

// Tab screens for HomeScreen
import 'package:daaymn/discover_screen.dart';
import 'package:daaymn/your_likes_screen.dart';
import 'package:daaymn/liked_you_screen.dart';
import 'package:daaymn/messages_screen.dart';
import 'package:daaymn/settings_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Global service instances
final supabaseClient = supabase_pkg.Supabase.instance;
final navigatorKey = GlobalKey<NavigatorState>();

// -------------------- Main --------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // THIS IS THE CORRECT FIX BASED ON FLUTTER DOCUMENTATION
  // Revert to the pre-Flutter 3.16 behavior to avoid content being obscured
  // by system bars, which resolves the Play Console warning.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);

  await dotenv.load(fileName: ".env");

  // --- THIS IS THE FIX: Get the link before running the app ---
  final appLinks = AppLinks();
  final initialUri = await appLinks.getInitialLink();
  if (kDebugMode) {
    print('[DEEP_LINK_LOG] main(): The initial link is: $initialUri');
  }
  // ---------------------------------------------------------

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await ScreenProtector.protectDataLeakageOn();
  } catch (e) {
    if (kDebugMode) {
      print('Error securing app: $e');
    }
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      print('Caught error: ${details.exception}\n${details.stack}');
      ErrorWidget.builder = (FlutterErrorDetails errorDetails) => ErrorWidget(errorDetails.exception);
    }
  };

  await _initializeServices();

  // Check for in-app updates
  if (!kDebugMode) { // Optional: Don't check for updates in debug mode
    await InAppUpdateService().checkForUpdate();
  }

  // --- THIS IS THE FIX: Pass the link to MyApp ---
  runApp(MyApp(initialLink: initialUri));
}

Future<void> _initializeServices() async {
  try {
    await supabase_pkg.Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    await PushNotificationService().init();
    await serviceLocator.init();
  } catch (e, stackTrace) {
    if (kDebugMode) print('An unexpected error occurred during initialization: $e\n$stackTrace');
  }
}

// -------------------- MyApp --------------------
class MyApp extends StatelessWidget {
  // --- THIS IS THE FIX: Accept the link ---
  final Uri? initialLink;
  const MyApp({super.key, this.initialLink});
  // ---------------------------------------

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => MessageProvider()),
        Provider(
          create: (context) => RealtimeService(Supabase.instance.client),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Define a single, high-contrast text theme for Daaymnbow mode.
          // This forces ALL text to be black, ensuring readability.
          final daaymnbowTextTheme = TextTheme(
            bodyLarge: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black),
            bodyMedium: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black),
            bodySmall: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black),
            displayLarge: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black, fontWeight: FontWeight.bold),
            displayMedium: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black, fontWeight: FontWeight.bold),
            displaySmall: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black, fontWeight: FontWeight.bold),
            headlineLarge: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black, fontWeight: FontWeight.bold),
            headlineMedium: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black, fontWeight: FontWeight.bold),
            headlineSmall: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black, fontWeight: FontWeight.bold),
            labelLarge: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black),
            labelMedium: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black),
            labelSmall: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black),
            titleLarge: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black, fontWeight: FontWeight.bold),
            titleMedium: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black, fontWeight: FontWeight.bold),
            titleSmall: TextStyle(fontFamily: themeProvider.fontFamily, color: Colors.black, fontWeight: FontWeight.bold),
          ).apply(
            // This ensures any text style not explicitly defined above also gets the black color.
            bodyColor: Colors.black,
            displayColor: Colors.black,
          );

          // Define the standard base text theme
          final baseTextTheme = TextTheme(
            displayLarge: TextStyle(fontFamily: themeProvider.fontFamily),
            displayMedium: TextStyle(fontFamily: themeProvider.fontFamily),
            displaySmall: TextStyle(fontFamily: themeProvider.fontFamily),
            headlineLarge: TextStyle(fontFamily: themeProvider.fontFamily),
            headlineMedium: TextStyle(fontFamily: themeProvider.fontFamily),
            headlineSmall: TextStyle(fontFamily: themeProvider.fontFamily),
            titleLarge: TextStyle(fontFamily: themeProvider.fontFamily),
            titleMedium: TextStyle(fontFamily: themeProvider.fontFamily),
            titleSmall: TextStyle(fontFamily: themeProvider.fontFamily),
          );

          final lightTheme = ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent, brightness: Brightness.light),
            useMaterial3: true,
            scaffoldBackgroundColor: themeProvider.isDaaymnbow ? Colors.transparent : Colors.white,
            // THE FIX: Use the special Daaymnbow theme if active.
            textTheme: themeProvider.isDaaymnbow ? daaymnbowTextTheme : baseTextTheme.apply(bodyColor: Colors.black, displayColor: Colors.black),
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: TextStyle(color: themeProvider.isDaaymnbow ? Colors.black54 : Colors.grey[600]),
            ),
            listTileTheme: ListTileThemeData(
              subtitleTextStyle: TextStyle(color: themeProvider.isDaaymnbow ? Colors.black87 : Colors.black54),
            ),
          );

          final darkTheme = ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent, brightness: Brightness.dark),
            useMaterial3: true,
            scaffoldBackgroundColor: themeProvider.isDaaymnbow ? Colors.transparent : null,
            // THE FIX: Use the special Daaymnbow theme if active.
            textTheme: themeProvider.isDaaymnbow ? daaymnbowTextTheme : baseTextTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: TextStyle(color: themeProvider.isDaaymnbow ? Colors.black54 : Colors.grey[500]),
            ),
            listTileTheme: ListTileThemeData(
              subtitleTextStyle: TextStyle(color: themeProvider.isDaaymnbow ? Colors.black87 : Colors.grey),
            ),
          );

          return MaterialApp(
            title: 'Daaymn',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            builder: (context, child) {
              return Container(
                decoration: themeProvider.isDaaymnbow
                    ? const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
                    : null,
                child: child,
              );
            },
            home: AuthAndProfileHandler(initialURI: initialLink),
          );
        },
      ),
    );
  }
}

// ... (The rest of the file remains unchanged) ...


// -------------------- COMPLETE, CORRECTED AUTH AND PROFILE HANDLER --------------------

// This enum defines the possible authentication states for our handler widget.
// This enum defines the possible authentication states for our handler widget.
enum AuthState { initial, unauthenticated, authenticated, passwordRecovery, timeSyncFailed, emailVerified, showPasswordRecoveryDialog }

class AuthAndProfileHandler extends StatefulWidget {
  // --- THIS IS THE FIX: Accept the initial URI ---
  final Uri? initialURI;
  const AuthAndProfileHandler({super.key, this.initialURI});
  // ---------------------------------------------

  @override
  State<AuthAndProfileHandler> createState() => _AuthAndProfileHandlerState();
}

class _AuthAndProfileHandlerState extends State<AuthAndProfileHandler> {
  AuthState _authState = AuthState.initial;
  String? _recoveryToken;

  late final StreamSubscription<supabase_pkg.AuthState> _authSubscription;
  StreamSubscription<Uri?>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    _initializeDeepLinkHandling();

    _authSubscription = supabaseClient.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final event = data.event;

      if (kDebugMode) print('[DEEP_LINK_LOG] onAuthStateChange event: ${data.event}');

      if (event == supabase_pkg.AuthChangeEvent.passwordRecovery) {
        if (data.session?.accessToken != null) {
          if (kDebugMode) print('[DEEP_LINK_LOG] Password recovery event caught.');
          setState(() {
            _recoveryToken = data.session!.accessToken;
            // Show the dialog first
            _authState = AuthState.showPasswordRecoveryDialog;
          });
        }
      } else if (event == supabase_pkg.AuthChangeEvent.signedIn) {
        if (data.session != null && data.session!.user.emailConfirmedAt != null && _authState != AuthState.authenticated) {
          if (kDebugMode) print('[DEEP_LINK_LOG] Email verified event caught.');
          setState(() => _authState = AuthState.emailVerified);
        } else {
          _performTimeSyncCheck();
        }
      } else if (event == supabase_pkg.AuthChangeEvent.signedOut) {
        if (mounted) setState(() => _authState = AuthState.unauthenticated);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDeepLinkHandling() async {
    if (widget.initialURI != null) {
      if (kDebugMode) print('[DEEP_LINK_LOG] Processing initial link: ${widget.initialURI}');
      _processDeepLink(widget.initialURI!);
    } else {
      if (kDebugMode) print('[DEEP_LINK_LOG] No initial link. Checking session.');
      final currentSession = supabaseClient.client.auth.currentSession;
      if (currentSession == null) {
        if (mounted) setState(() => _authState = AuthState.unauthenticated);
      } else {
        _performTimeSyncCheck();
      }
    }

    _deepLinkSubscription = AppLinks().uriLinkStream.listen((uri) {
      if (uri != null && mounted) {
        if (kDebugMode) print('[DEEP_LINK_LOG] Processing stream link: $uri');
        _processDeepLink(uri);
      }
    });
  }

  Future<void> _processDeepLink(Uri uri) async {
    if (uri.host == 'reset-password' && uri.queryParameters.containsKey('access_token')) {
      if (kDebugMode) print('[DEEP_LINK_LOG] Password reset link detected.');
      final accessToken = uri.queryParameters['access_token']!;
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('password_recovery_email');

      if (email != null) {
        try {
          await supabase_pkg.Supabase.instance.client.auth.verifyOTP(token: accessToken, type: supabase_pkg.OtpType.recovery, email: email);
        } on supabase_pkg.AuthException catch (e) {
          if (kDebugMode) print('[DEEP_LINK_LOG] Password reset error: ${e.message}');
        }
      }
      return;
    }

    if (uri.host == 'auth-callback' && uri.queryParameters.containsKey('access_token')) {
      if (kDebugMode) print('[DEEP_LINK_LOG] Email verification link detected.');
      final accessToken = uri.queryParameters['access_token']!;
      try {
        await supabase_pkg.Supabase.instance.client.auth.verifyOTP(token: accessToken, type: supabase_pkg.OtpType.signup);
      } on supabase_pkg.AuthException catch (e) {
        if (kDebugMode) print('[DEEP_LINK_LOG] Email verification error: ${e.message}');
      }
      return;
    }

    if (kDebugMode) print('[DEEP_LINK_LOG] Unhandled link detected: $uri');
  }

  Future<void> _performTimeSyncCheck() async {
    if (!mounted) return;

    // This check prevents the race condition. If a dialog is already scheduled
    // to be shown, this function will stop and let the dialog take priority.
    if (_authState == AuthState.emailVerified || _authState == AuthState.showPasswordRecoveryDialog) {
      return;
    }

    try {
      final serverTimeResponse = await supabaseClient.client.rpc('get_server_timestamp');
      final serverTime = DateTime.parse(serverTimeResponse as String);
      final deviceTime = DateTime.now();
      if (serverTime.difference(deviceTime).abs() > const Duration(minutes: 5)) {
        if (mounted) setState(() => _authState = AuthState.timeSyncFailed);
      } else {
        if (mounted) setState(() => _authState = AuthState.authenticated);
      }
    } catch (e) {
      if (mounted) setState(() => _authState = AuthState.timeSyncFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print('[DEEP_LINK_LOG] Building with state: $_authState');
    switch (_authState) {
      case AuthState.initial:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case AuthState.showPasswordRecoveryDialog:
        return Scaffold(
          body: DaaymnDialog(
            title: 'Password Down?',
            message: "Daaymn, a memory lapse? No sweat. We'll get you a fresh password and back to swiping in no time.",
            buttonText: 'Let\'s Fix This',onButtonPressed: () => setState(() => _authState = AuthState.passwordRecovery),
          ),
        );

      case AuthState.passwordRecovery:
        return AuthScreen(
          onSignedIn: () {
            setState(() {
              _recoveryToken = null;
              _authState = AuthState.unauthenticated;
            });
            _performTimeSyncCheck();
          },
          accessToken: _recoveryToken,
        );

      case AuthState.unauthenticated:
        return AuthScreen(onSignedIn: _performTimeSyncCheck);

      case AuthState.emailVerified:
        return Scaffold(
          body: DaaymnDialog(
            title: "Daaymn, You're In!",message: "Your email's legit and you're ready to roll. Let's get you signed in.",
            buttonText: "Let's Go!",
            // This now correctly proceeds to the app instead of going back to login.
            onButtonPressed: _performTimeSyncCheck,
          ),
        );

      case AuthState.timeSyncFailed:
        return _buildTimeSyncFailedDialog();

      case AuthState.authenticated:
        Provider.of<NotificationProvider>(context, listen: false).initialize();
        return const ProfileChecker();

      default:
        return const Scaffold(body: Center(child: Text("An unexpected error occurred.")));
    }
  }

  Widget _buildTimeSyncFailedDialog() {
    return Scaffold(
      body: DaaymnDialog(
        title: 'Time Traveler Detected!',
        message: "Daaymn, are you from the future? Your phone's clock seems to be out of sync with reality. Our app needs the correct time to function. Please adjust your device's date and time settings and restart the app.",
        buttonText: 'Quit',
        onButtonPressed: () => SystemNavigator.pop(),
        secondButtonText: 'Try Again',
        onSecondButtonPressed: _performTimeSyncCheck,
      ),
    );
  }
}


// -------------------- ProfileChecker --------------------
enum ProfileState { loading, needsDisplaySettings, needsPermissions, needsProfile, ready }

class ProfileChecker extends StatefulWidget {
  const ProfileChecker({super.key});

  @override
  State<ProfileChecker> createState() => _ProfileCheckerState();
}

class _ProfileCheckerState extends State<ProfileChecker> {
  ProfileState _profileState = ProfileState.loading;
  Profile? _profile;

  final crypto_service.CryptographyService _cryptographyService = crypto_service.CryptographyService();
  final PushNotificationService _pushNotificationService = PushNotificationService();

  @override
  void initState() {
    super.initState();
    _checkUserProfile();
  }
  Future<void> _syncBlockList() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = supabaseClient.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabaseClient.client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', userId);

      final blockedUserIds = response.map((item) => item['blocked_id'] as String).toList();
      await prefs.setStringList('blocked_users', blockedUserIds);
      if (kDebugMode) {
        print('Daaymn - Synced block list: $blockedUserIds');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Daaymn - Error syncing block list: $e');
      }
    }
  }
  Future<void> _checkUserProfile() async {
    try {
      // On-boarding checks
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('has_seen_display_settings') ?? false)) {
        if (mounted) setState(() => _profileState = ProfileState.needsDisplaySettings);
        return;
      }
      if (!(prefs.getBool('has_seen_permissions') ?? false)) {
        if (mounted) setState(() => _profileState = ProfileState.needsPermissions);
        return;
      }

      // Profile fetch
      final userId = supabaseClient.client.auth.currentUser?.id;
      if (userId == null) {
         if (mounted) await supabaseClient.client.auth.signOut();
         return;
      }

      final response = await supabaseClient.client.from('profiles').select().eq('id', userId).maybeSingle();

      if (mounted) {
        if (response != null) {
          _onProfileLoaded(Profile.fromJson(response));
        } else {
          setState(() => _profileState = ProfileState.needsProfile);
        }
      }
    } catch (e) {
      if (mounted) {
        await supabaseClient.client.auth.signOut();
      }
    }
  }

  void _onProfileLoaded(Profile userProfile) {
    final userId = supabaseClient.client.auth.currentUser!.id;
    _cryptographyService.getOrCreateKeyPair(userId);
    _pushNotificationService.getAndStoreFCMToken();
    _syncBlockList();

    if (mounted) {
      setState(() {
        _profile = userProfile;
        _profileState = ProfileState.ready;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_profileState) {
      case ProfileState.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case ProfileState.needsDisplaySettings:
        return DisplaySettingsPage(onDone: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_seen_display_settings', true);
          _checkUserProfile();
        });
      case ProfileState.needsPermissions:
        return PermissionsScreen(onDone: () async {
           final prefs = await SharedPreferences.getInstance();
           await prefs.setBool('has_seen_permissions', true);
          _checkUserProfile();
        });
      case ProfileState.needsProfile:
        return CreateProfileScreen(onProfileSaved: _onProfileLoaded);
      case ProfileState.ready:
        if (_profile == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return HomeScreen(userProfile: _profile!);
    }
  }
}

// -------------------- HomeScreen --------------------
class HomeScreen extends StatefulWidget {
  final Profile userProfile;

  const HomeScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  late Profile _userProfile;
  Timer? _likeCountdownTimer;
  String _nextLikeCountdown = '';
  bool _isClaimingLike = false;
  Timer? _presenceTimer;

  supabase_pkg.RealtimeChannel? _profileChannel;
  final LikeService _likeService = LikeService();

  @override
  void initState() {
    super.initState();
    _userProfile = widget.userProfile;
    _pageController = PageController();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final prefs = await SharedPreferences.getInstance();
      final blockedUsers = prefs.getStringList('blocked_users') ?? [];
      final senderId = message.data['sender_id'] as String?;

      if (senderId != null && blockedUsers.contains(senderId)) {
        if (kDebugMode) {
          print('Foreground notification from blocked user $senderId. Discarding.');
        }
        return; // Silently discard notification
      }

      if (message.notification != null) {
        if (kDebugMode) {
          print('Displaying foreground notification: ${message.notification!.title}');
        }
      }
      if (mounted) {
        context.read<NotificationProvider>().refresh();
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _likeService.grantDailyLike();
      await _refetchProfile(); // Ensures UI has the latest profile data
      _setupListeners();
      _startLikeCountdownTimer();
      _startPresenceTimer();
      if (mounted) {
        final notificationProvider = context.read<NotificationProvider>();
        notificationProvider.refresh();
        _handlePageChanged(0, notificationProvider);

        if (_userProfile.interestedIn == null || _userProfile.interestedIn!.isEmpty) {
          _showInterestedInDialog();
        }
      }
    });
  }

  Future<void> _refetchProfile() async {
    final userId = supabaseClient.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabaseClient.client.from('profiles').select().eq('id', userId).single();
      if (mounted) {
        setState(() {
          _userProfile = Profile.fromJson(response);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refetching profile: $e');
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _profileChannel?.unsubscribe();
    _likeCountdownTimer?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  void _startPresenceTimer() {
    _updateLastSeen(); // Fire immediately on start
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _updateLastSeen();
    });
  }

  Future<void> _updateLastSeen() async {
    try {
      await supabaseClient.client.rpc('update_last_seen');
      if (kDebugMode) {
        print('[Presence] Successfully updated last_seen.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Presence] Error updating last_seen: $e');
      }
    }
  }

  void _startLikeCountdownTimer() {
    _likeCountdownTimer?.cancel();

    if (_userProfile.likeCount >= 6 || _userProfile.lastLikeGrantedAt == null) {
      if (mounted) {
        setState(() => _nextLikeCountdown = '');
      }
      return;
    }

    final nextGrantTime = _userProfile.lastLikeGrantedAt!.toUtc().add(const Duration(hours: 20));

    _likeCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nowUtc = DateTime.now().toUtc();
      final remaining = nextGrantTime.difference(nowUtc);

      if (!mounted) {
        timer.cancel();
        return;
      }

      if (remaining.isNegative) {
        timer.cancel();
        if (mounted) {
          setState(() => _nextLikeCountdown = 'Ready!');
        }
      } else {
        final hours = remaining.inHours.toString().padLeft(2, '0');
        final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
        if (mounted) {
          setState(() => _nextLikeCountdown = '$hours:$minutes:$seconds');
        }
      }
    });
  }
  
  Future<void> _handleClaimLikeTap() async {
    if (_nextLikeCountdown != 'Ready!') {
      if (mounted) {
        _showNextLikeDialog();
      }
      return;
    }

    if (_isClaimingLike) {
      return;
    }

    if (mounted) {
      setState(() => _isClaimingLike = true);
    }

    try {
      await supabaseClient.client.rpc('request_daily_like');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to claim like. Please try again in a moment.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isClaimingLike = false);
        }
      });
    }
  }

  Future<void> _showNextLikeDialog() async {
    String message;
    if (_userProfile.likeCount >= 6) {
      message = "Daaymn! You're maxed out with 6 likes. Go on, shoot your shot! You won't get another freebie 'til you use one.";
    } else if (_nextLikeCountdown.isEmpty || _nextLikeCountdown == 'Ready!') {
      message = "Your next free like is ready to drop. Go get 'em, tiger!";
    } else {
      message = "Patience, player. You get one free like every 20 hours, maxing out at 6. Your next one drops in $_nextLikeCountdown.";
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => DaaymnDialog(
          title: 'Free Like Timer',
          message: message,
          buttonText: 'Got It',
          onButtonPressed: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  Future<void> _showInterestedInDialog() async {
    final tempInterestedIn = List<String>.from(_userProfile.interestedIn ?? []);

    if (mounted) {
      final result = await showDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              final options = ['Male', 'Female', 'Other'];
              return AlertDialog(
                title: const Text('Who are you interested in?'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...options.map((interest) => CheckboxListTile(
                            title: Text(interest),
                            value: tempInterestedIn.contains(interest),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  tempInterestedIn.add(interest);
                                } else {
                                  tempInterestedIn.remove(interest);
                                }
                              });
                            },
                          )),
                      CheckboxListTile(
                        title: const Text('Everyone'),
                        value: tempInterestedIn.length == options.length,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              tempInterestedIn.clear();
                              tempInterestedIn.addAll(options);
                            } else {
                              tempInterestedIn.clear();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (tempInterestedIn.isNotEmpty) {
                        Navigator.of(context).pop(tempInterestedIn);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != null && mounted) {
        try {
          await supabaseClient.client.from('profiles').update({
            'interested_in': result,
          }).eq('id', _userProfile.id);
          setState(() {
            _userProfile = _userProfile.copyWith(interestedIn: result);
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save preference: ${e.toString()}')));
          }
        }
      }
    }
  }

  Future<void> _showDiscoverOutOfLikesDialog() async {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => DaaymnDialog(
          title: 'Out of Likes!',
          message: "Daaymn, you're out of likes! Don't let this one get away. Top up your likes for just R4.99 each and shoot your shot!",
          buttonText: 'Buy Likes',
          onButtonPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const BuyLikesScreen()));
          },
          secondButtonText: 'Maybe Later',
          onSecondButtonPressed: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  Future<void> _showYourLikesOutOfLikesDialog() async {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => DaaymnDialog(
          title: 'No Likes Left!',
          message: "No likes left to power up your Super Like! Buy a pack (from R4.99) to fill up the heart and send that Daaymn OTM.",
          buttonText: 'Buy Likes',
          onButtonPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const BuyLikesScreen()));
          },
          secondButtonText: 'Not Now',
          onSecondButtonPressed: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  Future<void> _showLikedYouOutOfLikesDialog() async {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => DaaymnDialog(
          title: 'No Likes Left!',
          message: "Daaymn! You need a like to accept a like. It's the circle of life. For just R4.99, you can make this match happen!",
          buttonText: 'Buy Likes',
          onButtonPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const BuyLikesScreen()));
          },
          secondButtonText: 'Maybe Later',
          onSecondButtonPressed: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  void _setupListeners() {
    _profileChannel?.unsubscribe();
    _profileChannel = supabaseClient.client
        .channel('public:profiles:id=eq.${widget.userProfile.id}')
        .onPostgresChanges(
      event: supabase_pkg.PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      filter: supabase_pkg.PostgresChangeFilter(
        type: supabase_pkg.PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.userProfile.id,
      ),
      callback: (payload) {
        if (mounted && payload.newRecord.isNotEmpty) {
          final updatedProfile = Profile.fromJson(payload.newRecord);
          setState(() {
            _userProfile = updatedProfile;
          });
          _startLikeCountdownTimer();
        }
      },
    ).subscribe();

    final messageProvider = context.read<MessageProvider>();
    messageProvider.subscribeToProfileChanges();
  }

  void _handlePageChanged(int index, NotificationProvider provider) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 1:
        provider.markYourLikesAsSeen();
        break;
      case 2:
        provider.markLikedYouAsSeen();
        break;
      case 3:
        provider.markMessagesAsSeen();
        break;
    }
  }

  void _navigateToProfile() {
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => CreateProfileScreen(
          profileToEdit: _userProfile,
          onProfileSaved: (updatedProfile) {
            setState(() => _userProfile = updatedProfile);
            Navigator.of(context).pop();
          },
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Daaymn ', style: TextStyle(fontFamily: 'Pacifico', color: Colors.white, fontSize: 24, shadows: [Shadow(blurRadius: 2, color: Colors.black38)])),
            const Text('| ', style: TextStyle(color: Colors.white, fontSize: 20)),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black38)],
                        ),
                        children: [
                          TextSpan(
                            text: '${_userProfile.likeCount}',
                            style: TextStyle(color: _userProfile.likeCount < 5 ? Colors.redAccent : Colors.white),
                          ),
                          const TextSpan(
                            text: ' Likes Left!',
                            style: TextStyle(
                              fontFamily: 'Pacifico',
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_userProfile.likeCount < 6 && _nextLikeCountdown.isNotEmpty)
                      GestureDetector(
                        onTap: _handleClaimLikeTap,
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _isClaimingLike
                                ? 'Claiming...'
                                : _nextLikeCountdown == 'Ready!'
                                    ? 'Ready! (Tap to claim)'
                                    : '$_nextLikeCountdown - free like!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Pacifico',
                                shadows: [Shadow(blurRadius: 2, color: Colors.black38)],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: GestureDetector(
                onTap: () {
                   if (mounted) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const BuyLikesScreen()));
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(64),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: Colors.white.withAlpha(51),
                        ),
                      ),
                      child: const Text(
                        'Buy',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 8.0,
                              color: Color(0xFFFFD700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: _navigateToProfile,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    child: ClipOval(
                      child: SizedBox.fromSize(
                        size: const Size.fromRadius(20),
                        child: (_userProfile.imageUrl != null && _userProfile.imageUrl!.isNotEmpty)
                            ? Image.network(
                                _userProfile.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 20),
                              )
                            : const Icon(Icons.person, size: 20),
                      ),
                    ),
                  ),
                  if (_userProfile.isVerified)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: VerifiedBadge(profile: _userProfile, size: 18),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => _handlePageChanged(index, context.read<NotificationProvider>()),
        children: [
          DiscoverScreen(
            userProfile: _userProfile,
            showOutOfLikesDialog: _showDiscoverOutOfLikesDialog,
          ),
          YourLikesScreen(
            showOutOfLikesDialog: _showYourLikesOutOfLikesDialog,
          ),
          LikedYouScreen(
            showOutOfLikesDialog: _showLikedYouOutOfLikesDialog,
          ),
          const MessagesScreen(),
          SettingsScreen(userProfile: _userProfile),
        ],
      ),
      bottomNavigationBar: BottomNavBar(pageController: _pageController, currentIndex: _currentIndex),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required PageController pageController,
    required int currentIndex,
  })  : _pageController = pageController,
        _currentIndex = currentIndex;

  final PageController _pageController;
  final int _currentIndex;

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
        );
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: false,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Discover'),
        BottomNavigationBarItem(
          icon: NotificationBadge(icon: Icons.favorite_outline, count: notificationProvider.yourLikesCount),
          label: 'Your Likes',
        ),
        BottomNavigationBarItem(
          icon: NotificationBadge(icon: Icons.whatshot, count: notificationProvider.likedYouCount),
          label: 'Liked You',
        ),
        BottomNavigationBarItem(
          icon: NotificationBadge(icon: Icons.chat_bubble_outline, count: notificationProvider.messagesCount),
          label: 'Messages',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}

class NotificationBadge extends StatelessWidget {
  final IconData icon;
  final int count;

  const NotificationBadge({super.key, required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
