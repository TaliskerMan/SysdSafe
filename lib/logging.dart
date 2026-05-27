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

/// Documentation for LogService.
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  File? _logFile;

  /// Documentation for init.
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

  /// Documentation for info.
  static void info(String message) {
    _instance._log('INFO', message);
  }

  /// Documentation for warning.
  static void warning(String message) {
    _instance._log('WARN', message);
  }

  /// Documentation for error.
  static void error(String message) {
    _instance._log('ERROR', message);
  }

  /// Documentation for getLogContents.
  static Future<String> getLogContents() async {
    if (_instance._logFile != null && await _instance._logFile!.exists()) {
      return await _instance._logFile!.readAsString();
    }
    return 'No logs found.';
  }
}
