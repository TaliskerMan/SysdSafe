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
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:sysdsafe/database.dart';
import 'package:sysdsafe/state.dart';

/// A screen that displays the systemd security directives reference.
///
/// It allows users to browse all parsed systemd security directives,
/// search/filter by name, and view the formatted markdown explanations.
class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({super.key});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen> {
  final ScrollController _scrollController = ScrollController();
  List<DirectiveExplanation> _allDirectives = [];
  List<DirectiveExplanation> _filteredDirectives = [];
  bool _isLoading = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Asynchronously queries the `directives` table in SQLite, builds the list
  /// of [DirectiveExplanation]s sorted alphabetically, and updates the state.
  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('directives');

    final directives = maps
        .map(
          (map) => DirectiveExplanation(
            directive: map['directive']! as String,
            explanation: map['explanation']! as String,
            snippet: map['snippet']! as String,
          ),
        )
        .toList();

    directives.sort(
      (a, b) => a.directive.toLowerCase().compareTo(b.directive.toLowerCase()),
    );

    setState(() {
      _allDirectives = directives;
      _filteredDirectives = directives;
      _isLoading = false;
    });
  }

  /// Filters the list of directives to match those whose name contains the search query.
  void _filter(String query) {
    setState(() {
      _filteredDirectives = _allDirectives
          .where((d) => d.directive.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Systemd Security Reference',
            style: TextStyle(
              fontSize: appState.fontSizeBase + 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Explore the raw documentation extracted from your local man pages.',
            style: TextStyle(fontSize: appState.fontSizeBase),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Search Directives',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _filter,
                ),
              ),
              const SizedBox(width: 8),
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: ListView.builder(
                      controller: _scrollController,
                    itemCount: _filteredDirectives.length,
                    itemBuilder: (context, index) {
                      final item = _filteredDirectives[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ExpansionTile(
                          title: Text(
                            item.directive,
                            style: TextStyle(
                              fontSize: appState.fontSizeBase + 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: MarkdownBody(
                                data: item.explanation,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    fontSize: appState.fontSizeBase,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  strong: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  blockquoteDecoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF002855)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black12,
                                    ),
                                  ),
                                  blockquote: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ),
          ),
        ],
      ),
    );
  }
}
