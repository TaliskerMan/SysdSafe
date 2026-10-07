// Copyright (C) 2026 Chuck Talk <cwtalk1@gmail.com>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sysdsafe/paths.dart';

/// Service class that provides centralized logging for the SysdSafe application.
///
/// Writes formatted messages to a local file in the state directory and standard console.
class LogService {
  factory LogService() => _instance;
  LogService._internal();
  static final LogService _instance = LogService._internal();

  File? _logFile;

  /// Initialize the logging service.
  ///
  /// Resolves the state directory (see [sysdsafeStateDir]: `/var/lib/sysdsafe`
  /// when running as root), creating it if needed, and establishes the target
  /// log file handle.
  Future<void> init() async {
    final stateDir = await sysdsafeStateDir();
    _logFile = File('${stateDir.path}/app.log');
  }

  /// Full path of the log file, or null before [init].
  static String? get logFilePath => _instance._logFile?.path;

  void _log(String level, String message) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final logLine = '[$timestamp] [$level] $message';

    // Print to console for development/debug
    debugPrint(logLine);

    // Append to file (CP-ChangeComments: Fixed double-escaped newline)
    if (_logFile != null) {
      _logFile!.writeAsStringSync('$logLine\n', mode: FileMode.append);
    }
  }

  /// Log an information message.
  static void info(String message) {
    _instance._log('INFO', message);
  }

  /// Log a warning message.
  static void warning(String message) {
    _instance._log('WARN', message);
  }

  /// Log an error message.
  static void error(String message) {
    _instance._log('ERROR', message);
  }

  /// Read and return the complete contents of the application log file.
  static Future<String> getLogContents() async {
    if (_instance._logFile != null && await _instance._logFile!.exists()) {
      return _instance._logFile!.readAsString();
    }
    return 'No logs found.';
  }
}
