
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _fontFamily = 'Pacifico';
  bool _isDaaymnbow = false;

  ThemeMode get themeMode => _themeMode;
  String get fontFamily => _fontFamily;
  bool get isDaaymnbow => _isDaaymnbow;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    _fontFamily = prefs.getString('fontFamily') ?? 'Pacifico';
    _isDaaymnbow = prefs.getBool('isDaaymnbow') ?? false;
    notifyListeners();
  }

  void setTheme(ThemeMode themeMode) async {
    // FIX: The check now also verifies that Daaymnbow is off. If Daaymnbow is on,
    // this method will always run, allowing the user to switch back to a normal theme.
    if (_themeMode == themeMode && !_isDaaymnbow) return;

    _themeMode = themeMode;
    _isDaaymnbow = false; // Always disable Daaymnbow when a specific theme is chosen
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', themeMode == ThemeMode.dark);
    await prefs.setBool('isDaaymnbow', false);
  }

  void setDaaymnbow(bool isDaaymnbow) async {
    if (_isDaaymnbow == isDaaymnbow) return;

    _isDaaymnbow = isDaaymnbow;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDaaymnbow', isDaaymnbow);
  }

  void setFont(String fontFamily) async {
    if (_fontFamily == fontFamily) return;

    _fontFamily = fontFamily;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontFamily', fontFamily);
  }
}
