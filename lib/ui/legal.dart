import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../state.dart';
import 'widgets/page_container.dart';

/// Screen widget that displays the application license terms and copyright information.
class LegalScreen extends StatefulWidget {
  /// Constructor for [LegalScreen].
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String licenseText = 'Loading license...';

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    try {
      final file = File('LICENSE');
      if (await file.exists()) {
        final content = await file.readAsString();
        setState(() {
          licenseText = content;
        });
      } else {
        setState(() {
          licenseText =
              'LICENSE file not found. SysdSafe is licensed under the Affero GNU GPL v3 License.';
        });
      }
    } catch (e) {
      setState(() {
        licenseText = 'Could not read license file: \$e';
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
              padding: const EdgeInsets.all(24.0),
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
                      Image.asset('assets/noln.png', height: 64),
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
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
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
      ],
    );
  }
}
