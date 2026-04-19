import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

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

class SysdSafeApp extends StatelessWidget {
  const SysdSafeApp({Key? key}) : super(key: key);

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
            textTheme: GoogleFonts.notoSansTextTheme(ThemeData.light().textTheme).apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
            ),
            scaffoldBackgroundColor: Colors.white,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.green,
            textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme).apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
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

class InitializerScreen extends StatefulWidget {
  const InitializerScreen({Key? key}) : super(key: key);

  @override
  _InitializerScreenState createState() => _InitializerScreenState();
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

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
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
            icon: Icon(appState.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
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
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Reference'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Legal'),
        ],
      ),
    );
  }
}
