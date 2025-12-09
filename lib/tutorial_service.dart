import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const String _prefix = 'tutorial_';
  static const String _seenKey = 'has_seen_tutorial';
  static final TutorialService _instance = TutorialService._internal();
  late SharedPreferences _prefs;
  bool _initialized = false;

  factory TutorialService() {
    return _instance;
  }

  TutorialService._internal();

  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  Future<bool> shouldShowTutorial(String pageKey) async {
    if (!_initialized) await init();
    // Returns true if the tutorial has NOT been seen
    return !(_prefs.getBool('$_prefix$pageKey') ?? false);
  }

  Future<void> markTutorialAsSeen(String pageKey) async {
    if (!_initialized) await init();
    await _prefs.setBool('$_prefix$pageKey', true);
    
    // Also set a global flag that the user has seen any tutorial
    await _prefs.setBool(_seenKey, true);
  }

  // Check if user has seen any tutorial before
  Future<bool> hasSeenAnyTutorial() async {
    if (!_initialized) await init();
    return _prefs.getBool(_seenKey) ?? false;
  }

  // Reset all tutorial states (for testing or if needed)
  Future<void> resetAllTutorials() async {
    if (!_initialized) await init();
    final keys = _prefs.getKeys().where((key) => key.startsWith(_prefix)).toList();
    for (var key in keys) {
      await _prefs.remove(key);
    }
    await _prefs.remove(_seenKey);
  }
}
