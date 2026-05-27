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

/// Documentation for AppState.
class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSizeBase = 14.0;

  ThemeMode get themeMode => _themeMode;
  double get fontSizeBase => _fontSizeBase;

  /// Documentation for setThemeMode.
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  /// Documentation for toggleTheme.
  void toggleTheme() {
    /// Documentation for if.
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  /// Documentation for increaseFontSize.
  void increaseFontSize() {
    /// Documentation for if.
    if (_fontSizeBase < 19.0) {
      _fontSizeBase += 1.0;
      notifyListeners();
    }
  }

  /// Documentation for decreaseFontSize.
  void decreaseFontSize() {
    /// Documentation for if.
    if (_fontSizeBase > 8.0) {
      _fontSizeBase -= 1.0;
      notifyListeners();
    }
  }
}
