import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../scanner.dart';
import '../engine/recommendations.dart';
import '../state.dart';
import '../database.dart';
import '../logging.dart';

class ServiceDetailScreen extends StatefulWidget {
  final SystemdService service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final scanner = SystemdScanner();
  List<Vulnerability> vulnerabilities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final vulns = await scanner.scanServiceDetails(widget.service.name);
    setState(() {
      vulnerabilities = vulns;
      isLoading = false;
    });
  }

  Future<void> _applyAutoFix(List<HardeningAdvice> tier1Advice) async {
    final serviceName = widget.service.name;

    // ShadowAgent Rule: Input Validation & Path Traversal Prevention
    // Explicitly reject any service names containing directory separators or parent paths
    // to guarantee that no arbitrary files are targeted.
    if (serviceName.contains('/') || serviceName.contains('..')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Invalid service name format.')),
        );
      }
      return;
    }

    final dirPath = '/etc/systemd/system/$serviceName.d';
    final filePath = '$dirPath/sysdsafe-tier1.conf';

    setState(() => isLoading = true);

    try {
      // ShadowAgent Rule: Implement a reversible safety net for users
      // Before applying any fix, we capture the exact current state of the service.
      // Used '--' to prevent option injection if the service name starts with a hyphen.
      final catResult = await Process.run('systemctl', [
        'cat',
        '--',
        serviceName,
      ]);
      if (catResult.exitCode == 0) {
        final originalContent = catResult.stdout.toString();

        LogService.info('Backing up $serviceName before auto-fix...');

        // 1. Save to SQLite Database
        await DatabaseHelper.instance.backupServiceState(
          serviceName,
          originalContent,
        );

        // 2. Save to Plain Text File for Live USB recovery
        final homeDir = Platform.environment['HOME'] ?? '/root';
        final backupDir = Directory('$homeDir/sysdsafe_backups');
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        final backupFile = File('${backupDir.path}/$serviceName.backup');
        await backupFile.writeAsString(originalContent);
        LogService.info('Backup saved to ${backupFile.path}');
      } else {
        // ShadowAgent Rule: "First, do no harm"
        // If the backup mechanism fails, abort the auto-fix process entirely.
        // Continuing without a valid backup would put the system in an unrecoverable state.
        throw Exception(
          'Systemctl cat failed. Aborting auto-fix to ensure system safety.',
        );
      }
    } catch (e) {
      LogService.error('Backup failed for $serviceName: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-Fix aborted due to backup failure: $e')),
        );
      }
      setState(() => isLoading = false);
      return; // Do NOT proceed if backup fails
    }

    String fileContent = '[Service]\\n';
    for (var advice in tier1Advice) {
      fileContent += '${advice.snippet}\\n';
    }

    // ShadowAgent Rule: Prevent Shell Injection & Command Execution vulnerabilities
    // Do NOT interpolate user-controlled variables (like serviceName) directly into shell strings.
    // Instead, pass them as positional arguments ($1, $2, etc.) to the `sh -c` script to guarantee safe handling by the OS.
    // Use '--' with systemctl to prevent option injection if the service name starts with a hyphen.
    final command =
        'mkdir -p "\$1" && printf "%b\\n" "\$2" > "\$3" && systemctl daemon-reload && systemctl try-restart -- "\$4"';

    try {
      final result = await Process.run('pkexec', [
        'sh',
        '-c',
        command,
        '--',
        dirPath,
        fileContent,
        filePath,
        serviceName,
      ]);
      if (result.exitCode == 0) {
        LogService.info('Auto-Fix applied successfully for $serviceName');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auto-Fix applied successfully! Backups saved.'),
            ),
          );
        }
      } else {
        LogService.error('Auto-Fix failed for $serviceName: ${result.stderr}');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed: ${result.stderr}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    await _loadDetails();
  }

  Future<void> _revertAutoFix() async {
    final serviceName = widget.service.name;

    // ShadowAgent Rule: Input Validation & Path Traversal Prevention
    if (serviceName.contains('/') || serviceName.contains('..')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Invalid service name format.')),
        );
      }
      return;
    }

    final filePath = '/etc/systemd/system/$serviceName.d/sysdsafe-tier1.conf';

    // ShadowAgent Rule: Prevent Shell Injection & Command Execution vulnerabilities
    // Use positional arguments to safely pass file paths and service names to pkexec.
    // Use '--' with systemctl and rm to prevent option injection.
    final command =
        'rm -f -- "\$1" && systemctl daemon-reload && systemctl try-restart -- "\$2"';

    setState(() => isLoading = true);
    try {
      final result = await Process.run('pkexec', [
        'sh',
        '-c',
        command,
        '--',
        filePath,
        serviceName,
      ]);
      if (result.exitCode == 0) {
        LogService.info('Auto-Fix reverted successfully for $serviceName');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Auto-Fix reverted! Original config available in ~/sysdsafe_backups/',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        LogService.error('Revert failed for $serviceName: ${result.stderr}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Revert failed: ${result.stderr}')),
          );
        }
      }
    } catch (e) {
      LogService.error('Revert execution error for $serviceName: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    await _loadDetails();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group vulnerabilities by Tier
    final Map<int, List<HardeningAdvice>> tieredAdvice = {1: [], 2: [], 3: []};

    for (var vuln in vulnerabilities) {
      final advice = RecommendationEngine.getAdvice(vuln.name);
      tieredAdvice[advice.tier]?.add(advice);
    }

    final bool isDangerousService =
        widget.service.name.startsWith('user@') ||
        widget.service.name.contains('greeter');

    return Scaffold(
      appBar: AppBar(title: Text(widget.service.name)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    // ShadowAgent Rule: "First, do no harm".
                    // Provide a persistent warning so users don't break their entire system at once.
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Card(
                        color: isDark ? Colors.amber[900] : Colors.amber[100],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: isDark
                                    ? Colors.white
                                    : Colors.amber[900],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'SAFETY WARNING: First, do no harm.\nPlease make changes one at a time and restart your system to rescan before making several modifications at once. This ensures you do not accidentally lock yourself out of required functionality.',
                                  style: TextStyle(
                                    fontSize: appState.fontSizeBase,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.amber[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: isDangerousService
                        ? Card(
                            color: isDark ? Colors.red[900] : Colors.red[100],
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.red[900],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'CRITICAL WARNING',
                                        style: TextStyle(
                                          fontSize: appState.fontSizeBase + 4,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.red[900],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Do NOT modify or harden this service. Hardening ${widget.service.name} can lock you out of your system. Auto-fix has been disabled to protect your system.',
                                    style: TextStyle(
                                      fontSize: appState.fontSizeBase,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.red[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Card(
                            color: isDark ? Colors.grey[850] : Colors.blue[50],
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'How to Secure This Service',
                                    style: TextStyle(
                                      fontSize: appState.fontSizeBase + 4,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '1. Open terminal.\n'
                                    '2. Run `sudo systemctl edit ${widget.service.name}`.\n'
                                    '3. Answer the questions below and add the relevant snippets under [Service].\n'
                                    '4. Save and close, then run `sudo systemctl restart ${widget.service.name}`.',
                                    style: TextStyle(
                                      fontSize: appState.fontSizeBase,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Tier 1
                  if (tieredAdvice[1]!.isNotEmpty) ...[
                    isDangerousService
                        ? _buildTierHeader(
                            'Tier 1: Quick Wins (Low Risk) - AUTO-FIX DISABLED',
                            Colors.green,
                            appState,
                          )
                        : _buildTierHeaderWithActions(
                            'Tier 1: Quick Wins (Low Risk)',
                            Colors.green,
                            appState,
                            onAutoFix: () => _applyAutoFix(tieredAdvice[1]!),
                            onRevert: () => _revertAutoFix(),
                          ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildAdviceCard(
                          tieredAdvice[1]![index],
                          appState,
                          isDark,
                        ),
                        childCount: tieredAdvice[1]!.length,
                      ),
                    ),
                  ],

                  // Tier 2
                  if (tieredAdvice[2]!.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    _buildTierHeader(
                      'Tier 2: Contextual Hardening (Medium Risk)',
                      Colors.orange,
                      appState,
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildAdviceCard(
                          tieredAdvice[2]![index],
                          appState,
                          isDark,
                        ),
                        childCount: tieredAdvice[2]!.length,
                      ),
                    ),
                  ],

                  // Tier 3
                  if (tieredAdvice[3]!.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    _buildTierHeader(
                      'Tier 3: Advanced Isolation (High Risk)',
                      Colors.redAccent,
                      appState,
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildAdviceCard(
                          tieredAdvice[3]![index],
                          appState,
                          isDark,
                        ),
                        childCount: tieredAdvice[3]!.length,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTierHeader(String title, Color color, AppState appState) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: appState.fontSizeBase + 4,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildTierHeaderWithActions(
    String title,
    Color color,
    AppState appState, {
    required VoidCallback onAutoFix,
    required VoidCallback onRevert,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: appState.fontSizeBase + 4,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: onAutoFix,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(
                'Auto-Fix',
                style: TextStyle(fontSize: appState.fontSizeBase),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onRevert,
              icon: const Icon(Icons.undo),
              label: Text(
                'Revert',
                style: TextStyle(fontSize: appState.fontSizeBase),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdviceCard(
    HardeningAdvice advice,
    AppState appState,
    bool isDark,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    advice.humanQuestion,
                    style: TextStyle(
                      fontSize: appState.fontSizeBase + 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copy Snippet',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: advice.snippet));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied snippet!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              advice.humanAdvice,
              style: TextStyle(
                fontSize: appState.fontSizeBase,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.code,
                    size: 16,
                    color: isDark ? Colors.greenAccent : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    advice.snippet,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: appState.fontSizeBase,
                      color: isDark ? Colors.greenAccent : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
