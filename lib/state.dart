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
import 'package:sysdsafe/database.dart';
import 'package:sysdsafe/logging.dart';

/// Manages global application state, including active theme and base font size configurations.
class AppState extends ChangeNotifier {
  AppState() {
    loadSavedPreferences();
  }

  ThemeMode _themeMode = ThemeMode.system;
  double _fontSizeBase = 14;
  String? _lastModifiedService;

  ThemeMode get themeMode => _themeMode;
  double get fontSizeBase => _fontSizeBase;

  /// Human-readable label for the current theme mode.
  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light Theme';
      case ThemeMode.dark:
        return 'Dark Theme';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  /// Icon representing the current theme mode.
  IconData get themeModeIcon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  /// The name of the systemd service unit that was most recently modified.
  /// (CP-Comments: Added for single-service change safety enforcement)
  String? get lastModifiedService => _lastModifiedService;

  /// Loads saved theme mode and font size preferences from SQLite.
  Future<void> loadSavedPreferences() async {
    try {
      final savedTheme = await DatabaseHelper.instance.getSetting('theme_mode');
      if (savedTheme != null) {
        if (savedTheme == 'light') {
          _themeMode = ThemeMode.light;
        } else if (savedTheme == 'dark') {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }
      }

      final savedFont = await DatabaseHelper.instance.getSetting('font_size');
      if (savedFont != null) {
        final parsed = double.tryParse(savedFont);
        if (parsed != null && parsed >= 8.0 && parsed <= 19.0) {
          _fontSizeBase = parsed;
        }
      }
      notifyListeners();
    } catch (e) {
      LogService.error('Failed to load saved preferences: $e');
    }
  }

  /// Sets or clears the active modified service name.
  /// (CP-ChangeComments: Enables enforcement of modifying only one service at a time)
  void setLastModifiedService(String? serviceName) {
    _lastModifiedService = serviceName;
    notifyListeners();
  }

  /// Update the active theme mode and persist to database.
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _saveTheme();
  }

  /// Toggle the theme mode between system, light, and dark values.
  void toggleTheme() {
    if (_themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.light;
    } else if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
    _saveTheme();
  }

  void _saveTheme() {
    final modeStr = _themeMode == ThemeMode.light
        ? 'light'
        : _themeMode == ThemeMode.dark
            ? 'dark'
            : 'system';
    DatabaseHelper.instance.saveSetting('theme_mode', modeStr).catchError((e) {
      LogService.error('Failed to save theme mode: $e');
    });
  }

  void _saveFontSize() {
    DatabaseHelper.instance
        .saveSetting('font_size', _fontSizeBase.toString())
        .catchError((e) {
      LogService.error('Failed to save font size: $e');
    });
  }

  /// Increase the font size by 1.0pt up to a maximum of 19.0pt.
  void increaseFontSize() {
    if (_fontSizeBase < 19.0) {
      _fontSizeBase += 1.0;
      notifyListeners();
      _saveFontSize();
    }
  }

  /// Decrease the font size by 1.0pt down to a minimum of 8.0pt.
  void decreaseFontSize() {
    if (_fontSizeBase > 8.0) {
      _fontSizeBase -= 1.0;
      notifyListeners();
      _saveFontSize();
    }
  }
}
