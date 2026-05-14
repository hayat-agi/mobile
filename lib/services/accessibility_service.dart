import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance =
      AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  static const _keyTheme = 'acc_theme';
  static const _keyFontScale = 'acc_font_scale';
  static const _keyColorBlind = 'acc_color_blind';

  ThemeMode _themeMode = ThemeMode.system;
  double _fontScale = 1.0;
  bool _colorBlindMode = false;

  ThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;
  bool get colorBlindMode => _colorBlindMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_keyTheme) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[idx.clamp(0, ThemeMode.values.length - 1)];
    _fontScale = (prefs.getDouble(_keyFontScale) ?? 1.0).clamp(1.0, 1.5);
    _colorBlindMode = prefs.getBool(_keyColorBlind) ?? false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTheme, mode.index);
  }

  Future<void> setFontScale(double scale) async {
    if (_fontScale == scale) return;
    _fontScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontScale, scale);
  }

  Future<void> setColorBlindMode(bool enabled) async {
    if (_colorBlindMode == enabled) return;
    _colorBlindMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyColorBlind, enabled);
  }

  // Deuteranopia (red-green) compensation matrix
  static const colorBlindMatrix = <double>[
    0.80, 0.20, 0.00, 0, 0,
    0.26, 0.74, 0.00, 0, 0,
    0.00, 0.14, 0.86, 0, 0,
    0,    0,    0,    1, 0,
  ];
}
