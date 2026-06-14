// Copyright (C) 2026 Chuck Talk <cwtalk1@gmail.com>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

import 'package:flutter/material.dart';

/// Manages global application state, including active theme and base font size configurations.
class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSizeBase = 14.0;

  ThemeMode get themeMode => _themeMode;
  double get fontSizeBase => _fontSizeBase;

  /// Update the active theme mode.
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  /// Toggle the theme mode between system, dark, and light values.
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

  /// Increase the font size by 1.0pt up to a maximum of 19.0pt.
  void increaseFontSize() {
    if (_fontSizeBase < 19.0) {
      _fontSizeBase += 1.0;
      notifyListeners();
    }
  }

  /// Decrease the font size by 1.0pt down to a minimum of 8.0pt.
  void decreaseFontSize() {
    if (_fontSizeBase > 8.0) {
      _fontSizeBase -= 1.0;
      notifyListeners();
    }
  }
}
