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
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../logging.dart';
import '../state.dart';

/// A screen that displays the system and application logs to the user.
///
/// It provides options to refresh the logs, copy them to the system clipboard,
/// or draft a support email with the logs appended as context.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _logs = 'Loading logs...';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  /// Asynchronously loads the application logs from the storage and updates the state.
  Future<void> _loadLogs() async {
    final contents = await LogService.getLogContents();
    if (mounted) {
      setState(() {
        _logs = contents;
      });
    }
  }

  /// Launches the user's default email app pre-populated with support details
  /// and the last 5000 characters of the application log.
  Future<void> _emailSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@nordheim.online',
      queryParameters: {
        'subject': 'SysdSafe Support Request',
        // Provide instructions since the body might be too large for mailto
        'body':
            'Please describe your issue here:\\n\\n\\n--- LOGS BELOW ---\\n\\n${_logs.length > 5000 ? _logs.substring(_logs.length - 5000) : _logs}',
      },
    );

    try {
      if (!await launchUrl(emailLaunchUri)) {
        throw Exception('Could not launch email client.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open email client: $e')),
        );
      }
    }
  }

  /// Copies the currently displayed logs to the system clipboard.
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _logs));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs copied to clipboard!')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Application Logs',
                style: TextStyle(
                  fontSize: appState.fontSizeBase + 6,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Logs',
                    onPressed: _loadLogs,
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy to Clipboard',
                    onPressed: _copyToClipboard,
                  ),
                  ElevatedButton.icon(
                    onPressed: _emailSupport,
                    icon: const Icon(Icons.email),
                    label: Text(
                      'Email Support',
                      style: TextStyle(fontSize: appState.fontSizeBase),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black87 : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[400]!,
                ),
              ),
              child: SingleChildScrollView(
                reverse: true, // Auto-scroll to the bottom
                child: Text(
                  _logs,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: appState.fontSizeBase - 2,
                    color: isDark ? Colors.greenAccent : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
