
import 'package:daaymn/globals.dart';
import 'package:daaymn/legal_screen.dart';
import 'package:daaymn/main.dart';
import 'package:daaymn/polls_screen.dart';
import 'package:daaymn/push_notification_service.dart';
import 'package:daaymn/report_problem_screen.dart';
import 'package:daaymn/services/promo_code_service.dart';
import 'package:daaymn/services/service_locator.dart';
import 'package:daaymn/theme_provider.dart';
import 'package:daaymn/tutorial_overlay.dart';
import 'package:daaymn/tutorial_service.dart';
import 'package:daaymn/utils/face_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SettingsScreen extends StatefulWidget {
  final Profile userProfile;
  const SettingsScreen({super.key, required this.userProfile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = 'Loading...';

  final TutorialService _tutorialService = TutorialService();
  static const String _pageKey = 'settings_v2'; // Reset tutorial
  List<ShowcaseItem>? _showcaseItems;
  int _currentShowcaseStep = -1;

  final ScrollController _scrollController = ScrollController();

  // Keys for tutorial items
  final _signOutKey = GlobalKey();
  final _deleteAccountKey = GlobalKey();
  final _verifyProfileKey = GlobalKey(); // New key for verification
  final _interestsKey = GlobalKey();
  final _pollsKey = GlobalKey();
  final _themeKey = GlobalKey();
  final _fontKey = GlobalKey();
  final _notificationsKey = GlobalKey();
  final _termsKey = GlobalKey();
  final _privacyKey = GlobalKey();
  final _contactKey = GlobalKey();
  final _reportProblemKey = GlobalKey();
  final _ghostModeKey = GlobalKey();

  bool _isScreenCaptureOn = false;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getAppVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndShowTutorial());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'Version ${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'Failed to get version';
        });
      }
    }
  }

  Future<void> _checkAndShowTutorial() async {
    final shouldShow = await _tutorialService.shouldShowTutorial(_pageKey);
    if (shouldShow && mounted) {
      final items = _setupShowcase();
      final firstValidItemIndex = items.indexWhere((item) => item.key.currentContext != null);
      if (firstValidItemIndex != -1) {
        _scrollToItemAndShow(items, firstValidItemIndex);
      }
    }
  }

  Future<void> _scrollToItemAndShow(List<ShowcaseItem> items, int index) async {
    if (!mounted || index < 0 || index >= items.length) {
      _endTutorial();
      return;
    }

    final key = items[index].key;
    if (key.currentContext == null) {
      _endTutorial();
      return;
    }

    await Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 300),
      alignment: 0.5,
    );

    await Future.delayed(const Duration(milliseconds: 350));

    if (mounted) {
      setState(() {
        _showcaseItems = items;
        _currentShowcaseStep = index;
      });
    }
  }

  List<ShowcaseItem> _setupShowcase() {
    return [
      ShowcaseItem(key: _signOutKey, description: 'Sign out of your account here.'),
      ShowcaseItem(key: _deleteAccountKey, description: 'Delete your account permanently. This cannot be undone!'),
      ShowcaseItem(key: _verifyProfileKey, description: 'Verify your profile to prove you\'re a real person and get a badge!'),
      ShowcaseItem(key: _interestsKey, description: 'Change who you\'re interested in seeing.'),
      ShowcaseItem(key: _pollsKey, description: 'Answer polls to improve your matches.'),
      ShowcaseItem(key: _themeKey, description: 'Customize the app\'s look and feel.'),
      ShowcaseItem(key: _fontKey, description: 'Change the app\'s font to match your style.'),
      ShowcaseItem(key: _notificationsKey, description: 'Manage your notification preferences.'),
      ShowcaseItem(key: _termsKey, description: 'Read our Terms of Service.'),
      ShowcaseItem(key: _privacyKey, description: 'Read our Privacy Policy.'),
      ShowcaseItem(key: _contactKey, description: 'Have an issue, or a Daaymn good idea? Contact us here.'),
      ShowcaseItem(key: _reportProblemKey, description: 'Report a bug or other problem with the app.'),
    ];
  }

  void _endTutorial() {
    _tutorialService.markTutorialAsSeen(_pageKey);
    if (mounted) {
      setState(() => _currentShowcaseStep = -1);
    }
  }

  void _nextShowcaseStep() {
    if (_showcaseItems == null) {
      _endTutorial();
      return;
    }
    final nextStep = _currentShowcaseStep + 1;
    if (nextStep < _showcaseItems!.length) {
      _scrollToItemAndShow(_showcaseItems!, nextStep);
    } else {
      _endTutorial();
    }
  }

  Future<void> _signOut() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await supabase.Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthAndProfileHandler()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This action is irreversible. All your data will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Deleting Account..."),
            ],
          ),
        ),
      ),
    );

    try {
      // The invoke method will throw a FunctionException for non-200 responses
      await supabase.Supabase.instance.client.functions.invoke('delete-account');

      await supabase.Supabase.instance.client.auth.signOut();

      // Pop the loading dialog before navigating
      if(navigator.canPop()) {
        navigator.pop();
      }

      scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text('Account deleted successfully.'),
        backgroundColor: Colors.green,
      ));

      navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthAndProfileHandler()),
              (route) => false
      );

    } catch (e) {
      // Pop the loading dialog
      if(navigator.canPop()) {
        navigator.pop();
      }

      String errorMessage = 'An unknown error occurred.';
      if (e is supabase.FunctionException) {
        final errorData = e.details as Map<String, dynamic>?;
        errorMessage = errorData?['error'] ?? e.toString();
      } else {
        errorMessage = e.toString();
      }

      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('Failed to delete account: $errorMessage'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _startVerificationProcess() async {
    if(mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FaceVerificationScreen(profile: widget.userProfile)),
      );
    }
  }

  Future<void> _showThemeDialog() async {
    if(mounted) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Light'),
                  value: ThemeMode.light,
                  groupValue: themeProvider.isDaaymnbow ? null : themeProvider.themeMode,
                  onChanged: (value) {
                    if (value != null) themeProvider.setTheme(value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark'),
                  value: ThemeMode.dark,
                  groupValue: themeProvider.isDaaymnbow ? null : themeProvider.themeMode,
                  onChanged: (value) {
                    if (value != null) themeProvider.setTheme(value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<bool>(
                  title: const Text('Daaymnbow Sprinkle'),
                  value: true,
                  groupValue: themeProvider.isDaaymnbow,
                  onChanged: (value) {
                    if (value != null) themeProvider.setDaaymnbow(value);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Future<void> _showFontDialog() async {
    if (mounted) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select Font'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Default'),
                  value: 'Pacifico',
                  groupValue: themeProvider.fontFamily,
                  onChanged: (value) {
                    if (value != null) themeProvider.setFont(value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Modern'),
                  value: 'Inter',
                  groupValue: themeProvider.fontFamily,
                  onChanged: (value) {
                    if (value != null) themeProvider.setFont(value);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Funky'),
                  value: 'Bungee',
                  groupValue: themeProvider.fontFamily,
                  onChanged: (value) {
                    if (value != null) themeProvider.setFont(value);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }
  
  Future<void> _showCorePreferencesDialog() async {
    final tempInterestedIn = List<String>.from(widget.userProfile.interestedIn ?? []);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final options = ['Male', 'Female', 'Other'];
            return AlertDialog(
              title: const Text('I am interested in...'),
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
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(tempInterestedIn);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      try {
        await supabase.Supabase.instance.client.from('profiles').update({
          'interested_in': result,
        }).eq('id', widget.userProfile.id);
      } catch (e) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to update preferences: ${e.toString()}')));
      }
    }
  }

  Future<void> _showPasswordDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Password'),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Password"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _passwordController.clear();
              },
            ),
            TextButton(
              child: const Text('Submit'),
              onPressed: () {
                if (_passwordController.text == 'Wh1sk3y') {
                  setState(() {
                    _isScreenCaptureOn = true;
                  });
                  ScreenProtector.preventScreenshotOff();
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect password')),
                  );
                }
                _passwordController.clear();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildScreenCaptureTile() {
    return SwitchListTile(
      title: const Text('Expose (Screen Capture)'),
      subtitle: const Text('Allows screen recording and screenshots when enabled.'),
      value: _isScreenCaptureOn,
      onChanged: (bool value) {
        if (value) {
          _showPasswordDialog();
        } else {
          setState(() {
            _isScreenCaptureOn = false;
          });
          ScreenProtector.preventScreenshotOn();
        }
      },
      secondary: const Icon(Icons.screenshot, color: Colors.blueGrey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final userId = supabase.Supabase.instance.client.auth.currentUser!.id;
    return Scaffold(
      body: Container(
        decoration: themeProvider.isDaaymnbow
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : null,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Settings', style: TextStyle(fontFamily: 'Pacifico', fontSize: 30, color: Theme.of(context).colorScheme.onSurface)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: supabase.Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).eq('id', userId),
                    builder: (context, snapshot) {
                      final userProfile = snapshot.hasData ? Profile.fromJson(snapshot.data!.first) : widget.userProfile;
                      final bool hasGhostMode = userProfile.hasPurchasedGhostMode ||
                          (userProfile.ghostModeUntil != null &&
                              userProfile.ghostModeUntil!.isAfter(DateTime.now()));
                      return ListView(
                        controller: _scrollController,
                        children: <Widget>[
                          _buildSectionHeader('Account'),
                          ListTile(
                            key: _signOutKey,
                            title: const Text('Sign Out'),
                            leading: const Icon(Icons.exit_to_app),
                            onTap: _signOut,
                          ),
                          ListTile(
                            key: _deleteAccountKey,
                            title: const Text('Delete Account'),
                            leading: const Icon(Icons.delete_forever, color: Colors.red),
                            textColor: Colors.red,
                            onTap: _deleteAccount,
                          ),
                          const Divider(),
                          _buildSectionHeader('Verification'),
                          ListTile(
                            key: _verifyProfileKey,
                            leading: Icon(userProfile.isVerified ? Icons.check_circle : Icons.security, color: userProfile.isVerified ? Colors.green : null),
                            title: Text(userProfile.isVerified ? 'Profile Verified' : 'Verify Your Profile'),
                            subtitle: userProfile.isVerified
                                ? const Text('You\'re an official, real person!')
                                : RichText(
                                    text: TextSpan(
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)),
                                      children: const <TextSpan>[
                                        TextSpan(text: 'Get your '),
                                        TextSpan(text: 'Daaymn', style: TextStyle(fontFamily: 'Pacifico')),
                                        TextSpan(text: ' verification badge!'),
                                      ],
                                    ),
                                  ),
                            onTap: userProfile.isVerified ? null : _startVerificationProcess,
                          ),
                          const Divider(),
                          _buildSectionHeader('Core Preferences'),
                          ListTile(
                            key: _interestsKey,
                            title: const Text('Interests'),
                            leading: const Icon(Icons.person_search_outlined),
                            onTap: _showCorePreferencesDialog,
                          ),
                          if (hasGhostMode)
                            SwitchListTile(
                              key: _ghostModeKey,
                              title: const Text('Ghost Mode'),
                              subtitle: const Text('Hide your online status from others'),
                              value: userProfile.isGhostModeEnabled,
                              onChanged: (bool value) async {
                                await supabase.Supabase.instance.client
                                    .from('profiles')
                                    .update({'is_ghost_mode_enabled': value})
                                    .eq('id', userId);
                              },
                              secondary: const Icon(Icons.visibility_off_outlined),
                            ),
                          const Divider(),
                          _buildSectionHeader('Polls'),
                          ListTile(
                            key: _pollsKey,
                            title: const Text('Answer Polls'),
                            leading: const Icon(Icons.poll_outlined),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: serviceLocator.promoCodeService,
                                  child: const PollsScreen(),
                                ),
                              ),
                            ),
                          ),
                          const Divider(),
                          _buildSectionHeader('Appearance'),
                          ListTile(
                            key: _themeKey,
                            title: const Text('Theme'),
                            leading: const Icon(Icons.palette_outlined),
                            onTap: _showThemeDialog,
                          ),
                          ListTile(
                            key: _fontKey,
                            title: const Text('Font'),
                            leading: const Icon(Icons.font_download_outlined),
                            onTap: _showFontDialog,
                          ),
                          const Divider(),
                          _buildSectionHeader('Notifications'),
                          ListTile(
                            key: _notificationsKey,
                            title: const Text('Notification Settings'),
                            leading: const Icon(Icons.notifications_outlined),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
                          ),
                          const Divider(),
                          _buildSectionHeader('Support & Legal'),
                          ListTile(
                            key: _termsKey,
                            title: const Text('Terms of Service'),
                            leading: const Icon(Icons.description_outlined),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(filePath: 'assets/legal/terms_of_service.md'))),
                          ),
                          ListTile(
                            key: _privacyKey,
                            title: const Text('Privacy Policy'),
                            leading: const Icon(Icons.privacy_tip_outlined),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen(filePath: 'assets/legal/privacy_policy.md'))),
                          ),
                          ListTile(
                            key: _contactKey,
                            title: const Text('Contact Support'),
                            leading: const Icon(Icons.help_outline),
                             onTap: () async {
                              final Uri emailLaunchUri = Uri(
                                scheme: 'mailto',
                                path: 'daaymnco@gmail.com',
                                queryParameters: {
                                    'subject': 'Daaymn Support Request'
                                }
                              );
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              if (await canLaunchUrl(emailLaunchUri)) {
                                 await launchUrl(emailLaunchUri);
                              } else {
                                 scaffoldMessenger.showSnackBar(
                                  const SnackBar(content: Text('Could not open email client.')),
                                );
                              }
                            },
                          ),
                           ListTile(
                            key: _reportProblemKey,
                            title: const Text('Report a Problem'),
                            leading: const Icon(Icons.bug_report_outlined, color: Colors.orange),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportProblemScreen())),
                          ),
                          _buildScreenCaptureTile(),
                          const Divider(),
                          ListTile(
                            title: const Text('App Info'),
                            subtitle: Text(_appVersion),
                            leading: const Icon(Icons.info_outline),
                            onTap: null, // Not interactive
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_showcaseItems != null && _currentShowcaseStep != -1)
              TutorialOverlay(
                items: _showcaseItems!,
                currentStep: _currentShowcaseStep,
                onNext: _nextShowcaseStep,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final PushNotificationService _pushNotificationService = PushNotificationService();
  bool _newMatches = true;
  bool _newMessages = true;
  bool _newLikes = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _newMatches = prefs.getBool('notifications_new_matches') ?? true;
      _newMessages = prefs.getBool('notifications_new_messages') ?? true;
      _newLikes = prefs.getBool('notifications_new_likes') ?? true;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    String? topic;
    switch (key) {
      case 'notifications_new_matches':
        topic = PushNotificationService.matchesTopic;
        break;
      case 'notifications_new_messages':
        topic = PushNotificationService.messagesTopic;
        break;
      case 'notifications_new_likes':
        topic = PushNotificationService.likesTopic;
        break;
    }

    if (topic != null) {
      if (value) {
        await _pushNotificationService.subscribeToTopic(topic);
      } else {
        await _pushNotificationService.unsubscribeFromTopic(topic);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('New Matches'),
            subtitle: const Text('When someone you liked likes you back'),
            value: _newMatches,
            onChanged: (val) {
              setState(() => _newMatches = val);
              _updateSetting('notifications_new_matches', val);
            },
          ),
          SwitchListTile(
            title: const Text('New Messages'),
            subtitle: const Text('When you receive a new message'),
            value: _newMessages,
            onChanged: (val) {
              setState(() => _newMessages = val);
              _updateSetting('notifications_new_messages', val);
            },
          ),
          SwitchListTile(
            title: const Text('New Likes'),
            subtitle: const Text('When someone likes your profile'),
            value: _newLikes,
            onChanged: (val) {
              setState(() => _newLikes = val);
              _updateSetting('notifications_new_likes', val);
            },
          ),
        ],
      ),
    );
  }
}
