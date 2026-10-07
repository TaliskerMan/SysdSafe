// Version 1.0.14 (single-sourced from pubspec.yaml)
// Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

import 'dart:ffi';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:sysdsafe/database.dart';
import 'package:sysdsafe/logging.dart';
import 'package:sysdsafe/paths.dart';
import 'package:sysdsafe/scanner.dart';
import 'package:sysdsafe/state.dart';
import 'package:sysdsafe/ui/about.dart';
import 'package:sysdsafe/ui/backups.dart';
import 'package:sysdsafe/ui/dashboard.dart';
import 'package:sysdsafe/ui/legal.dart';
import 'package:sysdsafe/ui/logs.dart';
import 'package:sysdsafe/ui/onboarding.dart';
import 'package:sysdsafe/ui/reference_screen.dart';
import 'package:sysdsafe/ui/service_list.dart';
import 'package:sysdsafe/desktop_launcher.dart';

/// Top-level FFI initialization function for sqlite3 dynamic library resolution.
/// (CP-ChangeComments: Overrides Linux sqlite3 lookup to load libsqlite3.so.0 cleanly if libsqlite3.so is missing)
void sysdsafeFfiInit() {
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so.0');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so');
      }
    });
  }
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // (CP-ChangeComments: Enforce privileged execution on Linux in release mode while allowing debug runs)
  if (!kDebugMode &&
      Platform.isLinux &&
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      !Platform.environment.containsKey('SYSDSAFE_ALLOW_UNPRIVILEGED')) {
    try {
      final uidCheck = Process.runSync('id', ['-u']);
      final isRoot = uidCheck.stdout.toString().trim() == '0';
      if (!isRoot) {
        // Unprivileged launch is not permitted. Re-execute via wrapper or pkexec.
        if (File('/usr/bin/sysdsafe').existsSync()) {
          Process.start('/usr/bin/sysdsafe', args, mode: ProcessStartMode.detached);
        } else {
          Process.start('pkexec', ['/opt/sysdsafe/sysdsafe', ...args],
              mode: ProcessStartMode.detached);
        }
        exit(0);
      }
    } catch (e) {
      stderr.writeln('Warning: Failed to verify EUID: $e');
    }
  }

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sysdsafeFfiInit();
    sqfliteFfiInit();
    databaseFactory = createDatabaseFactoryFfi(ffiInit: sysdsafeFfiInit);
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

/// Custom scroll behavior for desktop accessibility that enables mouse/trackpad drag
/// scrolling across all scrollable views.
class AccessibleDesktopScrollBehavior extends MaterialScrollBehavior {
  const AccessibleDesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
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
          scrollBehavior: const AccessibleDesktopScrollBehavior(),
          themeMode: appState.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            // System Noto Sans (falls back to the platform default). No
            // runtime font download: this process runs as root.
            textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'Noto Sans',
              bodyColor: Colors.black,
              displayColor: Colors.black,
            ),
            scaffoldBackgroundColor: Colors.white,
            scrollbarTheme: ScrollbarThemeData(
              thumbVisibility: const WidgetStatePropertyAll(true),
              trackVisibility: const WidgetStatePropertyAll(true),
              thickness: const WidgetStatePropertyAll(14.0),
              radius: const Radius.circular(8.0),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.dragged)) return Colors.blue[700];
                if (states.contains(WidgetState.hovered)) return Colors.blue;
                return Colors.black45;
              }),
              trackColor: const WidgetStatePropertyAll(Colors.black12),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Noto Sans',
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
            // Dark navy background
            scaffoldBackgroundColor: const Color(0xFF001F3F),
            cardColor: const Color(0xFF003366),
            scrollbarTheme: ScrollbarThemeData(
              thumbVisibility: const WidgetStatePropertyAll(true),
              trackVisibility: const WidgetStatePropertyAll(true),
              thickness: const WidgetStatePropertyAll(14.0),
              radius: const Radius.circular(8.0),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.dragged)) {
                  return Colors.lightBlueAccent;
                }
                if (states.contains(WidgetState.hovered)) {
                  return Colors.blueAccent;
                }
                return Colors.white54;
              }),
              trackColor: const WidgetStatePropertyAll(Colors.white12),
            ),
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkInit();
  }

  /// Checks if database is initialized, catching errors gracefully.
  /// (CP-ChangeComments: Wrapped in try/catch to display error screen on failures instead of hanging indefinitely)
  Future<void> _checkInit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final isInit = await DatabaseHelper.instance.isDatabaseInitialized();
      if (mounted) {
        setState(() {
          _isInitialized = isInit;
          _isLoading = false;
        });
      }
    } catch (error) {
      LogService.error('Database initialization check failed: $error');
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Database Initialization Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _checkInit,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Initialization'),
                ),
              ],
            ),
          ),
        ),
      );
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
      final auditDir = await sysdsafeStateDir();
      final auditFile = File(p.join(auditDir.path, 'hardening_audit.json'));
      var jsonData = '[]';
      if (await auditFile.exists()) {
        jsonData = await auditFile.readAsString();
      } else {
        LogService.error('hardening_audit.json not found. Run a scan first.');
        // If there's no data yet, we can still show empty viewer, but it's empty
      }

      // Read template from assets
      final htmlTemplate = await rootBundle.loadString(
        'assets/audit_viewer.html',
      );

      // Inject JSON data
      final htmlContent = htmlTemplate.replaceFirst(
        '/*INJECT_JSON_DATA*/[]/*END_INJECT_JSON_DATA*/',
        jsonData,
      );

      // Write the viewer where the desktop user's own browser can read it
      // (the root-only state dir is not readable by them), then open it as
      // that user — never as root.
      final viewerDir = await DesktopLauncher.userViewableDir();
      final viewerFile = File(p.join(viewerDir.path, 'audit_viewer.html'));
      await viewerFile.writeAsString(htmlContent);
      await DesktopLauncher.giveToUser(viewerFile);

      final uri = Uri.file(viewerFile.absolute.path);
      if (!await DesktopLauncher.open(uri)) {
        LogService.error('Could not open the audit viewer at ${viewerFile.path}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open your browser. The report is at ${viewerFile.path}',
              ),
            ),
          );
        }
      }
    } catch (error) {
      LogService.error('Error opening audit viewer: $error');
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
          PopupMenuButton<ThemeMode>(
            icon: Icon(appState.themeModeIcon),
            tooltip: 'Theme: ${appState.themeModeName} (Click to switch)',
            initialValue: appState.themeMode,
            onSelected: (mode) => appState.setThemeMode(mode),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ThemeMode.system,
                child: Row(
                  children: [
                    Icon(Icons.brightness_auto),
                    SizedBox(width: 8),
                    Text('System Default'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: ThemeMode.light,
                child: Row(
                  children: [
                    Icon(Icons.light_mode),
                    SizedBox(width: 8),
                    Text('Light Theme'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: ThemeMode.dark,
                child: Row(
                  children: [
                    Icon(Icons.dark_mode),
                    SizedBox(width: 8),
                    Text('Dark Theme'),
                  ],
                ),
              ),
            ],
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
                const BackupsScreen(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Backups',
          ),
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
