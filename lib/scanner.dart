import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'logging.dart';

class SystemdService {
  final String name;
  final String description;
  final double exposureScore;
  final String exposureLevel; // OK, MEDIUM, EXPOSED, UNSAFE
  final String icon;

  SystemdService({
    required this.name,
    required this.description,
    required this.exposureScore,
    required this.exposureLevel,
    required this.icon,
  });
}

class Vulnerability {
  final String name;
  final String description;
  final double exposure;

  Vulnerability({
    required this.name,
    required this.description,
    required this.exposure,
  });
}

class SystemdScanner {
  Future<List<SystemdService>> scanServices() async {
    List<SystemdService> services = [];
    try {
      final result = await Process.run('systemd-analyze', ['security', '--json=pretty']);
      if (result.exitCode == 0) {
        final String stdout = result.stdout as String;
        
        // Export to Audit/hardening_audit.json
        final auditDir = Directory(p.join(Directory.current.path, 'Audit'));
        if (!await auditDir.exists()) {
          await auditDir.create(recursive: true);
        }
        final auditFile = File(p.join(auditDir.path, 'hardening_audit.json'));
        await auditFile.writeAsString(stdout);

        final List<dynamic> jsonList = jsonDecode(stdout);
        for (var item in jsonList) {
          final String name = item['unit'] ?? '';
          final double score = double.tryParse(item['exposure'] ?? '0.0') ?? 0.0;
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
      }
    } catch (e) {
      LogService.error('Error scanning services: $e');
    }
    return services;
  }

  Future<List<Vulnerability>> scanServiceDetails(String serviceName) async {
    List<Vulnerability> vulnerabilities = [];
    try {
      // ShadowAgent Rule: Prevent Option Injection
      // Insert '--' before user-controlled input so a maliciously named service (e.g. "--help")
      // is treated as an argument rather than a command flag.
      final result = await Process.run('systemd-analyze', ['security', '--json=pretty', '--', serviceName]);
      if (result.exitCode == 0) {
        final List<dynamic> jsonList = jsonDecode(result.stdout as String);
        for (var item in jsonList) {
          // A vulnerability is present if 'set' is false (meaning the directive is NOT set)
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
      }
    } catch (e) {
      LogService.error('Error getting service details: $e');
    }
    return vulnerabilities;
  }
}
