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
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'state.dart';
import 'scanner.dart';
import 'logging.dart';
import 'ui/dashboard.dart';
import 'ui/service_list.dart';
import 'ui/about.dart';
import 'ui/legal.dart';
import 'ui/reference_screen.dart';
import 'ui/onboarding.dart';
import 'ui/logs.dart';
import 'database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await LogService().init();
  LogService.info('SysdSafe Application Started');

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const SysdSafeApp(),
    ),
  );
}

/// Root Widget of the SysdSafe application.
///
/// Builds a [MaterialApp] with support for system theme switching and initializes
/// a custom Noto Sans typography scheme.
class SysdSafeApp extends StatelessWidget {
  const SysdSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'SysdSafe',
          themeMode: appState.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            textTheme: GoogleFonts.notoSansTextTheme(
              ThemeData.light().textTheme,
            ).apply(bodyColor: Colors.black, displayColor: Colors.black),
            scaffoldBackgroundColor: Colors.white,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.green,
            textTheme: GoogleFonts.notoSansTextTheme(
              ThemeData.dark().textTheme,
            ).apply(bodyColor: Colors.white, displayColor: Colors.white),
            // Dark navy background
            scaffoldBackgroundColor: const Color(0xFF001F3F),
            cardColor: const Color(0xFF003366),
          ),
          home: const InitializerScreen(),
        );
      },
    );
  }
}

/// Screen widget that handles initial database checks.
///
/// Prompts the [OnboardingScreen] if the directives database is empty,
/// or redirects directly to the [MainScreen] if already initialized.
class InitializerScreen extends StatefulWidget {
  const InitializerScreen({super.key});

  @override
  State<InitializerScreen> createState() => _InitializerScreenState();
}

class _InitializerScreenState extends State<InitializerScreen> {
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkInit();
  }

  Future<void> _checkInit() async {
    final isInit = await DatabaseHelper.instance.isDatabaseInitialized();
    if (mounted) {
      setState(() {
        _isInitialized = isInit;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isInitialized ? const MainScreen() : const OnboardingScreen();
  }
}

/// Screen widget displaying the main tab navigation panel.
///
/// Integrates the [DashboardScreen], [ServiceListScreen], [ReferenceScreen],
/// [LogsScreen], [AboutScreen], and [LegalScreen] screens. Also hosts the action
/// triggers for restarting scans, scaling fonts, toggling themes, and launching the
/// HTML Audit Viewer in the system browser.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final scanner = SystemdScanner();
  List<SystemdService> services = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _scanServices();
  }

  /// Scan systemd services and refresh the list in the UI.
  Future<void> _scanServices() async {
    setState(() {
      isLoading = true;
    });
    final result = await scanner.scanServices();
    setState(() {
      services = result;
      isLoading = false;
    });
  }

  /// Generate and open the HTML audit viewer containing the results of the hardening scan.
  ///
  /// Reads raw scan JSON output from the local Audit folder, merges it with the
  /// HTML viewer template asset, writes the output to disk, and opens it in the browser.
  Future<void> _openAuditViewer() async {
    try {
      final auditDir = Directory(p.join(Directory.current.path, 'Audit'));
      final auditFile = File(p.join(auditDir.path, 'hardening_audit.json'));
      String jsonData = '[]';
      if (await auditFile.exists()) {
        jsonData = await auditFile.readAsString();
      } else {
        LogService.error('hardening_audit.json not found. Run a scan first.');
        // If there's no data yet, we can still show empty viewer, but it's empty
      }

      // Read template from assets
      final htmlTemplate = await rootBundle.loadString('assets/audit_viewer.html');
      
      // Inject JSON data
      final htmlContent = htmlTemplate.replaceFirst(
        '/*INJECT_JSON_DATA*/[]/*END_INJECT_JSON_DATA*/', 
        jsonData,
      );

      // Write to a file inside Audit/
      final viewerFile = File(p.join(auditDir.path, 'audit_viewer.html'));
      if (!await auditDir.exists()) {
        await auditDir.create(recursive: true);
      }
      await viewerFile.writeAsString(htmlContent);

      // Open in default browser
      final uri = Uri.file(viewerFile.absolute.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        LogService.error('Could not launch browser for $uri');
      }
    } catch (e) {
      LogService.error('Error opening audit viewer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SysdSafe'),
            const SizedBox(width: 8),
            Image.asset('assets/sysdsafe.png', height: 32),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open HTML Audit Viewer',
            onPressed: _openAuditViewer,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-scan',
            onPressed: _scanServices,
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            tooltip: 'Decrease Font',
            onPressed: appState.decreaseFontSize,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Increase Font',
            onPressed: appState.increaseFontSize,
          ),
          IconButton(
            icon: Icon(
              appState.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Toggle Theme',
            onPressed: appState.toggleTheme,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: [
                DashboardScreen(services: services),
                ServiceListScreen(services: services),
                const ReferenceScreen(),
                const LogsScreen(),
                const AboutScreen(),
                const LegalScreen(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Reference'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Logs',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Legal'),
        ],
      ),
    );
  }
}
