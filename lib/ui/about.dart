import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../database.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About SysdSafe',
            style: TextStyle(
              fontSize: appState.fontSizeBase + 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    style: TextStyle(fontSize: appState.fontSizeBase + 2, height: 1.5),
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
                  _buildFeatureItem(context, Icons.security, 'Live exposure analysis using systemd-analyze.'),
                  _buildFeatureItem(context, Icons.school, 'Educational insights for each security directive.'),
                  _buildFeatureItem(context, Icons.color_lens, 'Modern, theme-aware user interface with scalable typography.'),
                  _buildFeatureItem(context, Icons.verified_user, 'Developed under ShadowAgent rules with continuous SBOM generation.'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Syncing definitions from local man pages...')),
                      );
                      await DatabaseHelper.instance.syncDatabase();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sync complete!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync),
                    label: Text('Sync Definitions from Man Pages', style: TextStyle(fontSize: appState.fontSizeBase)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
