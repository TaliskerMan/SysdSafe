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
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'logging.dart';
import 'paths.dart';

/// Model class representing a Systemd unit service scanned by Systemd scanner.
class SystemdService {
  /// Name of the Systemd service unit.
  final String name;
  /// Service description.
  final String description;
  /// Overall exposure rating score.
  final double exposureScore;
  /// Descriptive exposure level assessment (e.g., OK, MEDIUM, EXPOSED, UNSAFE).
  final String exposureLevel;
  /// String/Unicode representation of the status emoticon.
  final String icon;

  /// Constructor for [SystemdService].
  SystemdService({
    required this.name,
    required this.description,
    required this.exposureScore,
    required this.exposureLevel,
    required this.icon,
  });
}

/// Model class representing an active vulnerability or security weakness in a service unit.
class Vulnerability {
  /// The Systemd configuration directive that is missing or insecurely set.
  final String name;
  /// The security risk description.
  final String description;
  /// Exposure impact score.
  final double exposure;

  /// Constructor for [Vulnerability].
  Vulnerability({
    required this.name,
    required this.description,
    required this.exposure,
  });
}

/// Scanner service wrapper to run `systemd-analyze security` command analysis.
class SystemdScanner {
  /// Scan all Systemd services and output detailed security status lists.
  ///
  /// Also exports the raw results to Audit/hardening_audit.json for offline viewing.
  Future<List<SystemdService>> scanServices() async {
    List<SystemdService> services = [];
    try {
      final result = await Process.run('systemd-analyze', ['security', '--json=pretty']);
      if (result.exitCode == 0) {
        final String stdout = result.stdout as String;

        // Export to the per-user state dir (NOT the CWD; see paths.dart).
        final auditDir = await sysdsafeStateDir();
        final auditFile = File(p.join(auditDir.path, 'hardening_audit.json'));
        await auditFile.writeAsString(stdout);

        services = parseSecurityList(stdout);
      }
    } catch (e) {
      LogService.error('Error scanning services: $e');
    }
    return services;
  }

  /// Parses the JSON emitted by `systemd-analyze security --json=pretty` (the
  /// all-services overview) into [SystemdService] records. Pure function so it
  /// can be unit-tested against captured sample output.
  static List<SystemdService> parseSecurityList(String jsonStr) {
    final List<SystemdService> services = [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    for (var item in jsonList) {
      final String name = item['unit'] ?? '';
      final double score = double.tryParse(item['exposure']?.toString() ?? '0.0') ?? 0.0;
      final String level = item['predicate'] ?? 'UNKNOWN';
      final String icon = item['happy'] ?? '';
      services.add(SystemdService(
        name: name,
        description: 'System service: $name',
        exposureScore: score,
        exposureLevel: level,
        icon: icon,
      ));
    }
    return services;
  }

  /// Scan the security details and retrieve vulnerabilities for the specified service name.
  Future<List<Vulnerability>> scanServiceDetails(String serviceName) async {
    List<Vulnerability> vulnerabilities = [];
    try {
      // ShadowAgent Rule: Prevent Option Injection
      // Insert '--' before user-controlled input so a maliciously named service (e.g. "--help")
      // is treated as an argument rather than a command flag.
      final result = await Process.run('systemd-analyze', ['security', '--json=pretty', '--', serviceName]);
      if (result.exitCode == 0) {
        vulnerabilities = parseServiceDetails(result.stdout as String);
      }
    } catch (e) {
      LogService.error('Error getting service details: $e');
    }
    return vulnerabilities;
  }

  /// Parses the per-service JSON from `systemd-analyze security <unit>` into the
  /// list of unset, exposure-bearing directives. Pure function so it can be
  /// unit-tested against captured sample output.
  static List<Vulnerability> parseServiceDetails(String jsonStr) {
    final List<Vulnerability> vulnerabilities = [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    for (var item in jsonList) {
      // A vulnerability is present if 'set' is false (the directive is NOT set).
      if (item['set'] == false) {
        final double exposure = double.tryParse(item['exposure']?.toString() ?? '0.0') ?? 0.0;
        if (exposure > 0) {
          vulnerabilities.add(Vulnerability(
            name: item['name'] ?? '',
            description: item['description'] ?? '',
            exposure: exposure,
          ));
        }
      }
    }
    return vulnerabilities;
  }
}
