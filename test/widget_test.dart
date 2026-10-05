// Copyright (C) 2026 Chuck Talk <cwtalk1@gmail.com>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sysdsafe/main.dart';
import 'package:sysdsafe/state.dart';

/// Main entry point for the SysdSafe widget and integration tests.
void main() {
  testWidgets('SysdSafe app smoke test', (tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => AppState(),
        child: const SysdSafeApp(),
      ),
    );

    // Verify that the initial screen shows a loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test('AccessibleDesktopScrollBehavior enables mouse drag and trackpad', () {
    const behavior = AccessibleDesktopScrollBehavior();
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
  });

  test('AppState correctly exposes and cycles theme modes and icons', () {
    final state = AppState();
    expect(state.themeMode, ThemeMode.system);
    expect(state.themeModeName, 'System Default');
    expect(state.themeModeIcon, Icons.brightness_auto);

    state.toggleTheme();
    expect(state.themeMode, ThemeMode.light);
    expect(state.themeModeName, 'Light Theme');
    expect(state.themeModeIcon, Icons.light_mode);

    state.toggleTheme();
    expect(state.themeMode, ThemeMode.dark);
    expect(state.themeModeName, 'Dark Theme');
    expect(state.themeModeIcon, Icons.dark_mode);

    state.toggleTheme();
    expect(state.themeMode, ThemeMode.system);
  });
}
