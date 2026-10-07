import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sysdsafe/desktop_launcher.dart';
import 'package:sysdsafe/state.dart';
import 'package:sysdsafe/ui/widgets/page_container.dart';

/// Screen widget that displays the application license terms and copyright information.
class LegalScreen extends StatefulWidget {
  /// Constructor for [LegalScreen].
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String licenseText = 'Loading license...';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Loads the GNU Affero General Public License v3 text into [licenseText].
  ///
  /// (CP-Comments & CP-ChangeComments): SysdSafe packages run as root or via
  /// launchers where Directory.current is not the repository root. This method
  /// first retrieves the license directly from the compiled Flutter asset bundle
  /// ('assets/LICENSE'). If running in an unbundled environment, it gracefully
  /// falls back to system documentation paths (/usr/share/doc/sysdsafe/copyright,
  /// /opt/sysdsafe/LICENSE) or repository root files before falling back to
  /// the embedded license header text.
  Future<void> _loadLicense() async {
    // 1. Primary mechanism: Load from Flutter asset bundle (bundled into app binary)
    try {
      final assetContent = await rootBundle.loadString('assets/LICENSE');
      if (assetContent.trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            licenseText = assetContent;
          });
        }
        return;
      }
    } catch (_) {
      // Asset bundle failed; fall back to candidate filesystem paths
    }

    // 2. Secondary fallback: Search candidate filesystem paths on Linux host
    final candidatePaths = <String>[
      'LICENSE',
      '/usr/share/doc/sysdsafe/copyright',
      '/usr/share/doc/sysdsafe/LICENSE',
      '/opt/sysdsafe/LICENSE',
      p.join(Directory.current.path, 'LICENSE'),
      p.join(File(Platform.resolvedExecutable).parent.path, 'LICENSE'),
      p.join(File(Platform.resolvedExecutable).parent.path, 'data', 'flutter_assets', 'assets', 'LICENSE'),
    ];

    for (final path in candidatePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.trim().isNotEmpty) {
            if (mounted) {
              setState(() {
                licenseText = content;
              });
            }
            return;
          }
        }
      } catch (_) {
        // Skip unreadable path and inspect next candidate
      }
    }

    // 3. Tertiary fallback: Display license notice and reference if unreadable
    if (mounted) {
      setState(() {
        licenseText =
            'SysdSafe is licensed under the GNU Affero General Public License v3 (AGPL-3.0).\n\n'
            'This program is free software: you can redistribute it and/or modify\n'
            'it under the terms of the GNU Affero General Public License as published by\n'
            'the Free Software Foundation, either version 3 of the License, or\n'
            '(at your option) any later version.\n\n'
            'For full license text, see: https://www.gnu.org/licenses/agpl-3.0.txt\n'
            'or inspect /usr/share/doc/sysdsafe/copyright after package installation.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PageContainer(
      title: 'Legal Information',
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copyright & Ownership',
                  style: TextStyle(
                    fontSize: appState.fontSizeBase + 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Copyright © ${DateTime.now().year} Chuck Talk, a Nordheim Online product.\nAll Rights Reserved.',
                  style: TextStyle(
                    fontSize: appState.fontSizeBase + 2,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'License: Affero GNU GPL v3',
                  style: TextStyle(
                    fontSize: appState.fontSizeBase + 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.',
                        style: TextStyle(
                          fontSize: appState.fontSizeBase + 2,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Image.asset('assets/sysdsafe.png', height: 64),
                    const SizedBox(width: 12),
                    // CP-NordheimLogo (116): Hyperlink Nordheim Online logo to https://nordheim.online
                    InkWell(
                      onTap: () => DesktopLauncher.open(
                        Uri.parse('https://nordheim.online'),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Tooltip(
                        message: 'Visit Nordheim Online (https://nordheim.online)',
                        child: Image.asset('assets/noln.png', height: 64),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: isDark ? Colors.black26 : Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Text(
                    licenseText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: appState.fontSizeBase,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
