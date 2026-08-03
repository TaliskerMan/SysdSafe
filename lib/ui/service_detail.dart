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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sysdsafe/database.dart';
import 'package:sysdsafe/engine/recommendations.dart';
import 'package:sysdsafe/hardening.dart';
import 'package:sysdsafe/logging.dart';
import 'package:sysdsafe/scanner.dart';
import 'package:sysdsafe/state.dart';

/// Absolute path to the installed privileged helper. When present (i.e. the
/// `.deb` is installed), apply/revert run `pkexec <helper> ...`, which polkit
/// matches to the named `online.nordheim.sysdsafe.*` actions so the user sees a
/// clear authorization prompt. When absent (e.g. `flutter run` during
/// development), we fall back to an inline, injection-safe `pkexec sh -c`.
const String kSysdSafeHelper = '/usr/lib/sysdsafe/sysdsafe-helper';

/// A screen displaying details, analyzed vulnerabilities, and hardening recommendations
/// for a specific systemd service.
///
/// It supports manual hardening copy/paste snippets, automated low-risk tier-1
/// hardening via [Process.run] (with safety backups), and reversion of fixes.
class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({required this.service, super.key});
  final SystemdService service;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final scanner = SystemdScanner();
  List<Vulnerability> vulnerabilities = [];
  bool isLoading = true;

  // CP-ChangeComments: Added pagination state for Tier 1 Quick Wins parameter review
  int _tier1Page = 0;
  static const int _pageSize = 2;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  /// Scans the service vulnerabilities and updates the UI state.
  Future<void> _loadDetails() async {
    final vulns = await scanner.scanServiceDetails(widget.service.name);
    setState(() {
      vulnerabilities = vulns;
      isLoading = false;
    });
  }

  /// Performs low-risk Tier 1 hardening changes automatically on the targeted systemd service.
  ///
  /// Safe steps are implemented to back up the current service definition to SQLite and
  /// plain text at `~/sysdsafe_backups/` before utilizing `pkexec` to securely write
  /// overriding configurations into `/etc/systemd/system/<service>.d/sysdsafe-tier1.conf`.
  Future<void> _applyAutoFix(List<HardeningAdvice> tier1Advice) async {
    final serviceName = widget.service.name;

    // ShadowAgent Rule: Input Validation & Path Traversal Prevention
    // Reject service names containing directory separators or parent paths so
    // no arbitrary files can be targeted.
    if (!Hardening.isSafeServiceName(serviceName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Invalid service name format.')),
        );
      }
      return;
    }

    final dirPath = '/etc/systemd/system/$serviceName.d';
    final filePath = '$dirPath/sysdsafe-tier1.conf';

    // Capture whether the unit is running now, so we can tell afterwards
    // whether hardening degraded a previously-healthy service.
    final wasActive = await _isServiceActive(serviceName);

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
    } catch (error) {
      LogService.error('Backup failed for $serviceName: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-Fix aborted due to backup failure: $error'),
          ),
        );
      }
      setState(() => isLoading = false);
      return; // Do NOT proceed if backup fails
    }

    // Build the drop-in body with REAL newlines so it is written byte-for-byte.
    final fileContent = Hardening.buildDropInContent(tier1Advice);

    try {
      final result = await _runPrivileged(
        helperArgs: ['apply', dirPath, filePath, serviceName, fileContent],
        // Dev fallback: inline, injection-safe script. Uses printf '%s' (NOT
        // '%b') so '%' specifiers and backslashes in the content are preserved.
        fallbackScript:
            r'mkdir -p "$1" && printf "%s" "$2" > "$3" && systemctl daemon-reload && systemctl try-restart -- "$4"',
        fallbackArgs: [dirPath, fileContent, filePath, serviceName],
      );
      if (result.exitCode == 0) {
        LogService.info('Auto-Fix applied successfully for $serviceName');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auto-Fix applied successfully! Backups saved.'),
            ),
          );
        }
        // P1-#4: close the safety loop — confirm the service is healthy, and
        // proactively offer one-click revert if hardening degraded it.
        await _verifyHealthAndOfferRevert(serviceName, wasActive);
      } else {
        LogService.error('Auto-Fix failed for $serviceName: ${result.stderr}');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed: ${result.stderr}')));
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    }
    await _loadDetails();
  }

  /// Displays a mandatory safety warning dialog before auto-fixing, ensuring the user
  /// reviews all proposed parameter changes and acknowledges the single-service change rule.
  /// (CP-ChangeComments: Enforces single service change safety warning dialog per user requirements)
  Future<void> _confirmAndApplyAutoFix(
    List<HardeningAdvice> adviceList,
    AppState appState,
  ) async {
    final serviceName = widget.service.name;

    // Single-service change policy check
    if (appState.lastModifiedService != null &&
        appState.lastModifiedService != serviceName) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Expanded(child: Text('Active Service Change Warning')),
            ],
          ),
          content: Text(
            'You previously modified "${appState.lastModifiedService}".\n\n'
            'SAFETY RULE: First, do no harm.\n'
            'We strongly recommend testing and restarting your system to verify "${appState.lastModifiedService}" before hardening another service.\n\n'
            'Do you still want to proceed with hardening "$serviceName"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
              ),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    if (!mounted) return;

    // Confirmation & Parameter Review Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Review Quick Wins: $serviceName'),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SAFETY WARNING: Please make changes to ONLY ONE service at a time. Restart and test system functionality before modifying another service.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'The following ${adviceList.length} low-risk parameter(s) will be applied to $serviceName:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: adviceList.length,
                    itemBuilder: (context, index) {
                      final advice = adviceList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            advice.snippet,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          subtitle: Text(advice.humanQuestion),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check),
              label: const Text('Confirm & Apply Auto-Fix'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      appState.setLastModifiedService(serviceName);
      await _applyAutoFix(adviceList);
    }
  }

  /// Runs a privileged operation. Prefers the installed polkit helper
  /// (`pkexec <helper> ...`), falling back to an inline `pkexec sh -c` script
  /// when the helper is not installed (development).
  Future<ProcessResult> _runPrivileged({
    required List<String> helperArgs,
    required String fallbackScript,
    required List<String> fallbackArgs,
  }) async {
    if (File(kSysdSafeHelper).existsSync()) {
      return Process.run('pkexec', [kSysdSafeHelper, ...helperArgs]);
    }
    // ShadowAgent Rule: never interpolate user-controlled values into the
    // script; pass them as positional arguments after `--`.
    return Process.run('pkexec', [
      'sh',
      '-c',
      fallbackScript,
      '--',
      ...fallbackArgs,
    ]);
  }

  /// Returns true if the given unit is currently `active`. Read-only and
  /// unprivileged; used to detect post-hardening degradation.
  Future<bool> _isServiceActive(String serviceName) async {
    try {
      final result = await Process.run('systemctl', [
        'is-active',
        '--',
        serviceName,
      ]);
      return result.stdout.toString().trim() == 'active';
    } catch (_) {
      return false;
    }
  }

  /// After an apply, checks whether a previously-active service is now failed or
  /// inactive and, if so, surfaces a one-tap revert action.
  Future<void> _verifyHealthAndOfferRevert(
    String serviceName,
    bool wasActive,
  ) async {
    if (!wasActive) return; // Nothing to degrade if it wasn't running.

    var failed = false;
    try {
      final isFailed = await Process.run('systemctl', [
        'is-failed',
        '--',
        serviceName,
      ]);
      // `is-failed` prints "failed" and exits 0 when the unit has failed.
      if (isFailed.stdout.toString().trim() == 'failed') failed = true;
    } catch (_) {}

    final stillActive = await _isServiceActive(serviceName);
    if (!failed && stillActive) return; // Healthy — nothing to do.

    LogService.error(
      'Service $serviceName is no longer healthy after hardening '
      '(failed=$failed, active=$stillActive). Offering revert.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$serviceName" did not stay healthy after hardening.'),
        duration: const Duration(seconds: 12),
        backgroundColor: Colors.red.shade700,
        action: SnackBarAction(
          label: 'Revert now',
          textColor: Colors.white,
          onPressed: _revertAutoFix,
        ),
      ),
    );
  }

  /// Reverts any automatically applied Tier 1 hardening configuration by removing the
  /// corresponding configuration file and reloading/restarting the service.
  Future<void> _revertAutoFix() async {
    final serviceName = widget.service.name;

    // ShadowAgent Rule: Input Validation & Path Traversal Prevention
    if (!Hardening.isSafeServiceName(serviceName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Invalid service name format.')),
        );
      }
      return;
    }

    final filePath = '/etc/systemd/system/$serviceName.d/sysdsafe-tier1.conf';

    setState(() => isLoading = true);
    try {
      final result = await _runPrivileged(
        helperArgs: ['revert', filePath, serviceName],
        // Dev fallback: injection-safe inline script ('--' guards option
        // injection on both rm and systemctl).
        fallbackScript:
            r'rm -f -- "$1" && systemctl daemon-reload && systemctl try-restart -- "$2"',
        fallbackArgs: [filePath, serviceName],
      );
      if (result.exitCode == 0) {
        LogService.info('Auto-Fix reverted successfully for $serviceName');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Auto-Fix reverted! Original config available in ~/sysdsafe_backups/',
              ),
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
    } catch (error) {
      LogService.error('Revert execution error for $serviceName: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    }
    await _loadDetails();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group vulnerabilities by Tier
    final tieredAdvice = <int, List<HardeningAdvice>>{1: [], 2: [], 3: []};

    for (final vuln in vulnerabilities) {
      final advice = RecommendationEngine.getAdvice(vuln.name);
      tieredAdvice[advice.tier]?.add(advice);
    }

    final isDangerousService =
        widget.service.name.startsWith('user@') ||
        widget.service.name.contains('greeter');

    return Scaffold(
      appBar: AppBar(title: Text(widget.service.name)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    // ShadowAgent Rule: "First, do no harm".
                    // Provide a persistent warning so users don't break their entire system at once.
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        color: isDark ? Colors.amber[900] : Colors.amber[100],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
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
                              padding: const EdgeInsets.all(16),
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
                              padding: const EdgeInsets.all(16),
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
                    if (isDangerousService)
                      _buildTierHeader(
                        'Tier 1: Quick Wins (Low Risk) - AUTO-FIX DISABLED',
                        Colors.green,
                        appState,
                      )
                    else
                      _buildTierHeaderWithActions(
                        'Tier 1: Quick Wins (Low Risk)',
                        Colors.green,
                        appState,
                        onAutoFix:
                            () => _confirmAndApplyAutoFix(
                              tieredAdvice[1]!,
                              appState,
                            ),
                        onRevert: _revertAutoFix,
                      ),
                    SliverToBoxAdapter(
                      child: _buildPaginationBar(
                        tieredAdvice[1]!.length,
                        appState,
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final totalTier1 = tieredAdvice[1]!.length;
                        final totalPages = (totalTier1 / _pageSize).ceil();
                        final safePage = _tier1Page.clamp(
                          0,
                          totalPages > 0 ? totalPages - 1 : 0,
                        );
                        final pagedAdvice =
                            tieredAdvice[1]!
                                .skip(safePage * _pageSize)
                                .take(_pageSize)
                                .toList();
                        if (index >= pagedAdvice.length) return null;
                        return _buildAdviceCard(
                          pagedAdvice[index],
                          appState,
                          isDark,
                        );
                      }, childCount: (tieredAdvice[1]!.length - (_tier1Page * _pageSize)).clamp(0, _pageSize)),
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

  /// Builds a pagination control bar for Quick Wins parameter lists.
  /// (CP-Comments: Docstring added for pagination bar control builder)
  Widget _buildPaginationBar(int totalItems, AppState appState) {
    final totalPages = (totalItems / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    final currentPageDisplay = _tier1Page + 1;
    final startItem = _tier1Page * _pageSize + 1;
    final endItem = (startItem + _pageSize - 1).clamp(1, totalItems);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page $currentPageDisplay of $totalPages (Showing $startItem-$endItem of $totalItems)',
                style: TextStyle(
                  fontSize: appState.fontSizeBase,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous Parameters',
                    onPressed: _tier1Page > 0
                        ? () {
                            setState(() {
                              _tier1Page--;
                            });
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next Parameters',
                    onPressed: _tier1Page < totalPages - 1
                        ? () {
                            setState(() {
                              _tier1Page++;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierHeader(String title, Color color, AppState appState) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 16),
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
        padding: const EdgeInsets.only(bottom: 8, top: 16),
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
        padding: const EdgeInsets.all(16),
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
