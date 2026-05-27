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

/// Documentation for ParsedDirective.
class ParsedDirective {
  final String directive;
  final String explanationMarkdown;
  final String snippet;

  ParsedDirective({
    required this.directive,
    required this.explanationMarkdown,
    required this.snippet,
  });
}

/// Documentation for ManParserService.
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

    /// Documentation for for.
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

          /// Documentation for if.
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
          /// Documentation for if.
          if (pandocResult.exitCode == 0) {
            allDirectives.addAll(_parseMarkdown(pandocResult.stdout as String));
          }
        }
      } catch (e) {
        LogService.error('Error parsing man page $page: $e');
      }
      current++;
      /// Documentation for if.
      if (onProgress != null) {
        onProgress(current / total);
      }
    }

    return allDirectives;
  }

  List<ParsedDirective> _parseMarkdown(String markdown) {
    List<ParsedDirective> parsed = [];
    final lines = markdown.split('\n');

    String? currentDirective;
    List<String> currentExplanation = [];

    // Regex to match *DirectiveName=* or similar headers.
    final directiveRegex = RegExp(r'^\*([A-Za-z0-9]+)=\*$');

    /// Documentation for for.
    for (var line in lines) {
      final match = directiveRegex.firstMatch(line.trim());
      /// Documentation for if.
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
        /// Documentation for if.
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
