import 'package:flutter/material.dart';
import 'dart:io';
import '../database.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isCheckingPandoc = true;
  bool _hasPandoc = false;
  bool _isSeeding = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkPandoc();
  }

  Future<void> _checkPandoc() async {
    setState(() {
      _isCheckingPandoc = true;
    });
    try {
      final result = await Process.run('pandoc', ['--version']);
      if (result.exitCode == 0) {
        setState(() {
          _hasPandoc = true;
        });
      }
    } catch (e) {
      // Pandoc not found
    }
    setState(() {
      _isCheckingPandoc = false;
    });
  }

  Future<void> _startSeeding() async {
    setState(() {
      _isSeeding = true;
      _progress = 0.0;
    });

    await DatabaseHelper.instance.seedDatabase(
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _progress = p;
          });
        }
      },
    );

    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SysdSafe Setup'),
            const SizedBox(width: 8),
            Image.asset('assets/sysdsafe.png', height: 32),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isCheckingPandoc
              ? const CircularProgressIndicator()
              : _isSeeding
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Ingesting System Directives...',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 10),
                    Text('${(_progress * 100).toStringAsFixed(0)}%'),
                  ],
                )
              : _hasPandoc
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Pandoc is installed.',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'We need to build the local database of systemd directives from your system man pages. This may take a moment.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _startSeeding,
                      child: const Text('Start Setup'),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      'Missing Dependency: Pandoc',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'SysdSafe requires pandoc to convert man pages to beautiful markdown. Please install pandoc (e.g., sudo apt install pandoc) and restart the application.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _checkPandoc,
                      child: const Text('Check Again'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
