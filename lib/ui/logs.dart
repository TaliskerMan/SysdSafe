import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../logging.dart';
import '../state.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  _LogsScreenState createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _logs = 'Loading logs...';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final contents = await LogService.getLogContents();
    if (mounted) {
      setState(() {
        _logs = contents;
      });
    }
  }

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
