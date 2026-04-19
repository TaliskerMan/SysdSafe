import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSizeBase = 14.0;

  ThemeMode get themeMode => _themeMode;
  double get fontSizeBase => _fontSizeBase;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  void increaseFontSize() {
    if (_fontSizeBase < 19.0) {
      _fontSizeBase += 1.0;
      notifyListeners();
    }
  }

  void decreaseFontSize() {
    if (_fontSizeBase > 8.0) {
      _fontSizeBase -= 1.0;
      notifyListeners();
    }
  }
}
