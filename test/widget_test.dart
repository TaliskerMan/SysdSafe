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
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sysdsafe/main.dart';
import 'package:sysdsafe/state.dart';

/// Main entry point for the SysdSafe widget and integration tests.
void main() {
  testWidgets('SysdSafe app smoke test', (WidgetTester tester) async {
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
}
