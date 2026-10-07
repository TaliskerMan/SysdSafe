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
import 'package:provider/provider.dart';
import 'package:sysdsafe/backup_service.dart';
import 'package:sysdsafe/logging.dart';
import 'package:sysdsafe/state.dart';

/// Screen widget displaying all systemd service configuration backups and modifications
/// made by SysdSafe, with the ability to review and restore to a known previous state.
/// (CP-ChangeComments: Dedicated interface for reviewing tool changes and executing clean rollbacks)
class BackupsScreen extends StatefulWidget {
  /// Constructor for [BackupsScreen].
  const BackupsScreen({this.backupService, super.key});

  /// Optional injected [BackupService] instance (useful for unit testing).
  final BackupService? backupService;

  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> {
  final ScrollController _scrollController = ScrollController();
  late final BackupService _backupService = widget.backupService ?? BackupService();

  List<BackupStatusItem> _backups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'ALL'; // ALL, ACTIVE, RESTORED

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the main listing to the top.
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Scrolls the main listing to the bottom.
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Loads all backup items and real-time override statuses from [BackupService].
  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final items = await _backupService.loadBackups();
      if (mounted) {
        setState(() {
          _backups = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.error('Failed to load backups: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load backups: $e')),
        );
      }
    }
  }

  /// Displays a modal dialog or bottom sheet showing the original service configuration
  /// before SysdSafe modifications were applied.
  void _showOriginalContentDialog(BackupStatusItem item, AppState appState) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.history, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Original: ${item.serviceName}',
                  style: TextStyle(fontSize: appState.fontSizeBase + 2),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 700,
            height: 450,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Snapshot taken: ${item.formattedDate}',
                  style: TextStyle(
                    fontSize: appState.fontSizeBase - 1,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (item.backupFilePath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'File on disk: ${item.backupFilePath}',
                      style: TextStyle(
                        fontSize: appState.fontSizeBase - 2,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        item.originalContent,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: appState.fontSizeBase - 1,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy to Clipboard'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: item.originalContent));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Original configuration copied!')),
                );
              },
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Displays a modal dialog showing the drop-in override applied by SysdSafe.
  void _showAppliedChangesDialog(BackupStatusItem item, AppState appState) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.security, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Applied Hardening: ${item.serviceName}',
                  style: TextStyle(fontSize: appState.fontSizeBase + 2),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 700,
            height: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location: /etc/systemd/system/${item.serviceName}.d/sysdsafe-tier1.conf',
                  style: TextStyle(
                    fontSize: appState.fontSizeBase - 1,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        item.dropInContent ?? '# No active drop-in configuration content found.',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: appState.fontSizeBase - 1,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (item.dropInContent != null)
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy to Clipboard'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: item.dropInContent!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Applied configuration copied!')),
                  );
                },
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Prompts a confirmation dialog and performs clean restoration of the service.
  /// (CP-ChangeComments: Protects against accidental reversions and resets single-service safety state)
  Future<void> _confirmAndRestoreService(BackupStatusItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.restore_page, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text('Confirm Restoration'),
            ],
          ),
          content: Text(
            'Are you sure you want to restore "${item.serviceName}" to its original state?\n\n'
            'This action will remove the SysdSafe override configuration '
            '(/etc/systemd/system/${item.serviceName}.d/sysdsafe-tier1.conf) '
            'and reload systemd to return the unit to its unhardened previous configuration.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Restore Service'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue[700],
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    final appState = Provider.of<AppState>(context, listen: false);
    final result = await _backupService.restoreService(item.serviceName);

    if (!mounted) return;

    if (result.success) {
      if (appState.lastModifiedService == item.serviceName) {
        appState.setLastModifiedService(null);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isHealthy
                ? result.message
                : '${result.message} (Warning: service did not return to active state)',
          ),
          backgroundColor: result.isHealthy ? Colors.green[700] : Colors.amber[800],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red[700],
        ),
      );
    }

    await _loadBackups();
  }

  /// Prompts confirmation to delete a stored backup snapshot.
  Future<void> _confirmAndDeleteBackup(BackupStatusItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Backup Snapshot?'),
          content: Text(
            'Delete the stored backup record for "${item.serviceName}"? '
            'This will remove the saved copy of the original service configuration.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _backupService.deleteBackup(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup for "${item.serviceName}" removed.')),
        );
      }
      await _loadBackups();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredBackups = _backups.where((b) {
      final matchesSearch = b.serviceName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      final matchesStatus = _filterStatus == 'ALL' ||
          (_filterStatus == 'ACTIVE' && b.isOverrideActive) ||
          (_filterStatus == 'RESTORED' && !b.isOverrideActive);
      return matchesSearch && matchesStatus;
    }).toList();

    final activeCount = _backups.where((b) => b.isOverrideActive).length;
    final cleanCount = _backups.where((b) => !b.isOverrideActive).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Changes & Backups',
                      style: TextStyle(
                        fontSize: appState.fontSizeBase + 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review service modifications, inspect original configurations, and cleanly restore to previous states.',
                      style: TextStyle(
                        fontSize: appState.fontSizeBase,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Backups',
                onPressed: _loadBackups,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Scroll to Top',
                onPressed: _scrollToTop,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                tooltip: 'Scroll to Bottom',
                onPressed: _scrollToBottom,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overview Statistics Summary Cards
          Row(
            children: [
              _buildStatCard(
                'Total Backups',
                '${_backups.length}',
                Icons.inventory_2,
                Colors.blueAccent,
                appState,
                isDark,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Active Changes',
                '$activeCount',
                Icons.security_update_good,
                Colors.orangeAccent,
                appState,
                isDark,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Restored / Original',
                '$cleanCount',
                Icons.check_circle_outline,
                Colors.greenAccent,
                appState,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search and Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search backups by service name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _filterStatus,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Records')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active Changes')),
                  DropdownMenuItem(value: 'RESTORED', child: Text('Restored / Clean')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _filterStatus = val;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Scrolling List Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredBackups.isEmpty
                    ? _buildEmptyState(appState, isDark)
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: filteredBackups.length,
                          itemBuilder: (context, index) {
                            return _buildBackupCard(
                              filteredBackups[index],
                              appState,
                              isDark,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Builds a small metric summary card.
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color accentColor,
    AppState appState,
    bool isDark,
  ) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: accentColor, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: appState.fontSizeBase - 2,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: appState.fontSizeBase + 4,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds an empty state notification when no backups or filtered results are found.
  Widget _buildEmptyState(AppState appState, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 64,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _filterStatus != 'ALL'
                  ? 'No matching backups found'
                  : 'No Systemd Service Changes or Backups Yet',
              style: TextStyle(
                fontSize: appState.fontSizeBase + 4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _filterStatus != 'ALL'
                  ? 'Try clearing the search query or status filter.'
                  : 'Whenever you apply Tier-1 hardening in the Services tab, SysdSafe automatically saves a full backup snapshot before making modifications. All historical backups and active drop-in overrides will appear here for one-click restoration.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: appState.fontSizeBase,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an individual backup card in the scrolling listing.
  Widget _buildBackupCard(
    BackupStatusItem item,
    AppState appState,
    bool isDark,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isOverrideActive
              ? Colors.orange.withValues(alpha: 0.5)
              : Colors.transparent,
          width: item.isOverrideActive ? 1.5 : 0,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dns,
                  color: isDark ? Colors.lightBlueAccent : Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.serviceName,
                    style: TextStyle(
                      fontSize: appState.fontSizeBase + 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  avatar: Icon(
                    item.isOverrideActive
                        ? Icons.security
                        : Icons.check_circle,
                    size: 16,
                    color: item.isOverrideActive
                        ? Colors.orangeAccent
                        : Colors.greenAccent,
                  ),
                  label: Text(
                    item.isOverrideActive ? 'Change Active' : 'Original State',
                    style: TextStyle(
                      fontSize: appState.fontSizeBase - 2,
                      fontWeight: FontWeight.bold,
                      color: item.isOverrideActive
                          ? Colors.orangeAccent
                          : Colors.greenAccent,
                    ),
                  ),
                  backgroundColor: item.isOverrideActive
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.green.withValues(alpha: 0.15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 4),
                Text(
                  'Backup Captured: ${item.formattedDate}',
                  style: TextStyle(
                    fontSize: appState.fontSizeBase - 2,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (item.backupFilePath != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.backupFilePath!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: appState.fontSizeBase - 2,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 24),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Original State'),
                      onPressed: () => _showOriginalContentDialog(item, appState),
                    ),
                    if (item.isOverrideActive)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.code, size: 16),
                        label: const Text('View Applied Changes'),
                        onPressed: () => _showAppliedChangesDialog(item, appState),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.isOverrideActive)
                      FilledButton.icon(
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('Restore to Original State'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                        ),
                        onPressed: () => _confirmAndRestoreService(item),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Delete Backup Snapshot',
                        onPressed: () => _confirmAndDeleteBackup(item),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
