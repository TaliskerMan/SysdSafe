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
import 'package:provider/provider.dart';
import '../state.dart';
import '../database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/page_container.dart';
import 'legal.dart';

/// Screen widget that displays general information, features, licensing, and
/// system manual page synchronization controls for SysdSafe.
class AboutScreen extends StatelessWidget {
  /// Constructor for [AboutScreen].
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return PageContainer(
      title: 'About SysdSafe',
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
                    'What is SysdSafe?',
                    style: TextStyle(
                      fontSize: appState.fontSizeBase + 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SysdSafe is a powerful, yet user-friendly graphical interface designed to help you secure your local Linux workstation. '
                    'It acts as a front-end to the built-in systemd security scanning capabilities, allowing you to easily visualize '
                    'vulnerabilities in your system services and apply necessary remediations without the guesswork.',
                    style: TextStyle(
                      fontSize: appState.fontSizeBase + 2,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Features:',
                    style: TextStyle(
                      fontSize: appState.fontSizeBase + 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    context,
                    Icons.security,
                    'Live exposure analysis using systemd-analyze.',
                  ),
                  _buildFeatureItem(
                    context,
                    Icons.school,
                    'Educational insights for each security directive.',
                  ),
                  _buildFeatureItem(
                    context,
                    Icons.color_lens,
                    'Modern, theme-aware user interface with scalable typography.',
                  ),
                  _buildFeatureItem(
                    context,
                    Icons.verified_user,
                    'Developed under ShadowAgent rules with continuous SBOM generation.',
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalScreen()));
                    },
                    icon: const Icon(Icons.gavel),
                    label: Text(
                      'Legal / License',
                      style: TextStyle(fontSize: appState.fontSizeBase),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3.',
                    style: TextStyle(fontSize: appState.fontSizeBase),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('https://github.com/TaliskerMan/SysdSafe')),
                    child: Text(
                      'Source code: https://github.com/TaliskerMan/SysdSafe',
                      style: TextStyle(fontSize: appState.fontSizeBase, color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Syncing definitions from local man pages...',
                          ),
                        ),
                      );
                      await DatabaseHelper.instance.syncDatabase();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sync complete!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync),
                    label: Text(
                      'Sync Definitions from Man Pages',
                      style: TextStyle(fontSize: appState.fontSizeBase),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

  /// Build a horizontal row representing a feature description and its icon.
  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    final appState = Provider.of<AppState>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white : Colors.black87),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: appState.fontSizeBase + 1),
            ),
          ),
        ],
      ),
    );
  }
}
