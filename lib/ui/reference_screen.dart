import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({Key? key}) : super(key: key);

  @override
  _ReferenceScreenState createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen> {
  List<DirectiveExplanation> _allDirectives = [];
  List<DirectiveExplanation> _filteredDirectives = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('directives');
    
    final directives = maps.map((map) => DirectiveExplanation(
      directive: map['directive'] as String,
      explanation: map['explanation'] as String,
      snippet: map['snippet'] as String,
    )).toList();

    directives.sort((a, b) => a.directive.toLowerCase().compareTo(b.directive.toLowerCase()));

    setState(() {
      _allDirectives = directives;
      _filteredDirectives = directives;
      _isLoading = false;
    });
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredDirectives = _allDirectives.where((d) => 
        d.directive.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
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
          TextField(
            decoration: InputDecoration(
              labelText: 'Search Directives',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _filter,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredDirectives.length,
                    itemBuilder: (context, index) {
                      final item = _filteredDirectives[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ExpansionTile(
                          title: Text(
                            item.directive, 
                            style: TextStyle(fontSize: appState.fontSizeBase + 2, fontWeight: FontWeight.bold)
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: MarkdownBody(
                                data: item.explanation,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(fontSize: appState.fontSizeBase, color: isDark ? Colors.white : Colors.black),
                                  strong: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                                  blockquoteDecoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF002855) : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                                  ),
                                  blockquote: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
