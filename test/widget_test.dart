import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sysdsafe/main.dart';
import 'package:sysdsafe/state.dart';

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
