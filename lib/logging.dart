import 'dart:io';
import 'package:flutter/foundation.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  File? _logFile;

  Future<void> init() async {
    final homeDir = Platform.environment['HOME'] ?? '/root';
    final stateDir = Directory('$homeDir/.local/state/sysdsafe');
    if (!await stateDir.exists()) {
      await stateDir.create(recursive: true);
    }
    _logFile = File('${stateDir.path}/app.log');
  }

  void _log(String level, String message) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final logLine = '[$timestamp] [$level] $message';
    
    // Print to console for development/debug
    debugPrint(logLine);

    // Append to file
    if (_logFile != null) {
      _logFile!.writeAsStringSync('$logLine\\n', mode: FileMode.append);
    }
  }

  static void info(String message) {
    _instance._log('INFO', message);
  }

  static void warning(String message) {
    _instance._log('WARN', message);
  }

  static void error(String message) {
    _instance._log('ERROR', message);
  }

  static Future<String> getLogContents() async {
    if (_instance._logFile != null && await _instance._logFile!.exists()) {
      return await _instance._logFile!.readAsString();
    }
    return 'No logs found.';
  }
}
