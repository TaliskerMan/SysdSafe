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
import 'logging.dart';

/// Model class representing a Systemd directive parsed from manual pages.
class ParsedDirective {
  /// Name of the directive (e.g., ProtectSystem).
  final String directive;
  /// Formatted explanation in Markdown.
  final String explanationMarkdown;
  /// Code snippet demonstrating how to configure the directive.
  final String snippet;

  /// Constructor for [ParsedDirective].
  ParsedDirective({
    required this.directive,
    required this.explanationMarkdown,
    required this.snippet,
  });
}

/// Service class that parses systemd directive manuals using `pandoc`.
class ManParserService {
  final List<String> targetManPages = [
    'systemd.exec',
    'systemd.resource-control',
    'systemd.kill',
    'systemd.service',
    'systemd.unit',
  ];

  Future<List<ParsedDirective>> parseAll({
    void Function(double)? onProgress,
  }) async {
    List<ParsedDirective> allDirectives = [];
    int total = targetManPages.length;
    int current = 0;

    for (String page in targetManPages) {
      try {
        // Find man page path
        final pathResult = await Process.run('man', ['-w', page]);
        if (pathResult.exitCode != 0) continue;

        final path = (pathResult.stdout as String).trim();
        if (path.isEmpty) continue;

        // Convert to markdown
        ProcessResult pandocResult;
        if (path.endsWith('.gz')) {
          final zcatProcess = await Process.start('zcat', [path]);
          final pandocProcess = await Process.start('pandoc', [
            '-f',
            'man',
            '-t',
            'markdown',
          ]);

          zcatProcess.stdout.pipe(pandocProcess.stdin);

          final pandocOutput = await pandocProcess.stdout
              .transform(SystemEncoding().decoder)
              .join();
          final exitCode = await pandocProcess.exitCode;

          if (exitCode == 0) {
            allDirectives.addAll(_parseMarkdown(pandocOutput));
          }
        } else {
          pandocResult = await Process.run('pandoc', [
            '-f',
            'man',
            '-t',
            'markdown',
            path,
          ]);
          if (pandocResult.exitCode == 0) {
            allDirectives.addAll(_parseMarkdown(pandocResult.stdout as String));
          }
        }
      } catch (e) {
        LogService.error('Error parsing man page $page: $e');
      }
      current++;
      if (onProgress != null) {
        onProgress(current / total);
      }
    }

    return allDirectives;
  }

  /// Parse the markdown text content converted from the manual page.
  List<ParsedDirective> _parseMarkdown(String markdown) {
    List<ParsedDirective> parsed = [];
    final lines = markdown.split('\n');

    String? currentDirective;
    List<String> currentExplanation = [];

    // Regex to match *DirectiveName=* or similar headers.
    final directiveRegex = RegExp(r'^\*([A-Za-z0-9]+)=\*$');

    for (var line in lines) {
      final match = directiveRegex.firstMatch(line.trim());
      if (match != null) {
        // Save previous if exists
        if (currentDirective != null && currentExplanation.isNotEmpty) {
          parsed.add(
            ParsedDirective(
              directive: currentDirective,
              explanationMarkdown: currentExplanation.join('\n').trim(),
              snippet: '$currentDirective=...',
            ),
          );
        }

        currentDirective = match.group(1);
        currentExplanation = [];
      } else if (line.startsWith('# ')) {
        // Save previous if we hit a new major section header
        if (currentDirective != null && currentExplanation.isNotEmpty) {
          parsed.add(
            ParsedDirective(
              directive: currentDirective,
              explanationMarkdown: currentExplanation.join('\n').trim(),
              snippet: '$currentDirective=...',
            ),
          );
        }
        currentDirective = null;
        currentExplanation = [];
      } else {
        if (currentDirective != null) {
          // Clean up blockquote markers inserted by pandoc
          currentExplanation.add(line.replaceFirst(RegExp(r'^>\s?'), ''));
        }
      }
    }

    // Catch the last one
    if (currentDirective != null && currentExplanation.isNotEmpty) {
      parsed.add(
        ParsedDirective(
          directive: currentDirective,
          explanationMarkdown: currentExplanation.join('\n').trim(),
          snippet: '$currentDirective=...',
        ),
      );
    }

    return parsed;
  }
}
