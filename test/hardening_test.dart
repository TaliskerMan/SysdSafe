// Copyright (C) 2026 Chuck Talk <cwtalk1@gmail.com>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

// Unit tests for the pure logic that matters most for safety: parsing
// systemd-analyze output, validating service names, and generating the
// privileged drop-in content (the byte-exact write that replaced printf %b).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sysdsafe/engine/recommendations.dart';
import 'package:sysdsafe/hardening.dart';
import 'package:sysdsafe/scanner.dart';

/// Reads a `NAME="..."` assignment from the root helper script.
List<String> _helperList(String name) {
  final script = File('linux/packaging/sysdsafe-helper').readAsStringSync();
  final match = RegExp('^$name="([^"]*)"\$', multiLine: true).firstMatch(script);
  expect(match, isNotNull, reason: '$name not found in sysdsafe-helper');
  return match!.group(1)!.split(' ').where((s) => s.isNotEmpty).toList();
}

void main() {
  group('Hardening.isSafeServiceName', () {
    test('accepts ordinary unit names', () {
      expect(Hardening.isSafeServiceName('sshd.service'), isTrue);
      expect(Hardening.isSafeServiceName('user@1000.service'), isTrue);
      expect(Hardening.isSafeServiceName(r'a\x2db.service'), isTrue);
    });

    test('rejects empty, path-separator and parent-ref names', () {
      expect(Hardening.isSafeServiceName(''), isFalse);
      expect(Hardening.isSafeServiceName('../etc/passwd'), isFalse);
      expect(Hardening.isSafeServiceName('foo/bar.service'), isFalse);
      expect(Hardening.isSafeServiceName('a..b'), isFalse);
    });

    test('rejects option-like, non-service and odd-character names', () {
      expect(Hardening.isSafeServiceName('-x.service'), isFalse);
      expect(Hardening.isSafeServiceName('foo.socket'), isFalse);
      expect(Hardening.isSafeServiceName('.service'), isFalse);
      expect(Hardening.isSafeServiceName('foo bar.service'), isFalse);
      expect(Hardening.isSafeServiceName('*.service'), isFalse);
    });
  });

  group('Hardening.isProtectedService', () {
    test('blocks services where Tier 1 can lock users out', () {
      for (final name in [
        'sshd.service',
        'ssh.service',
        'user@1000.service',
        'gdm3.service',
        'lightdm.service',
        'display-manager.service',
        'systemd-logind.service',
        'dbus.service',
        'getty@tty1.service',
        'cron.service',
        'docker.service',
        'NetworkManager.service',
        'lightdm-greeter.service',
        'cups.service',
        'cupsd.service',
        'cups-browsed.service',
      ]) {
        expect(Hardening.isProtectedService(name), isTrue, reason: name);
      }
    });

    test('allows ordinary standalone daemons', () {
      for (final name in [
        'avahi-daemon.service',
        'nginx.service',
        'bluetooth.service',
      ]) {
        expect(Hardening.isProtectedService(name), isFalse, reason: name);
      }
    });
  });

  group('Dart and root helper stay in sync', () {
    test('protected list matches PROTECTED_UNITS', () {
      expect(_helperList('PROTECTED_UNITS'), Hardening.protectedUnitPatterns);
    });

    test('allowlist matches ALLOWED_LINES and the Tier 1 snippets', () {
      expect(_helperList('ALLOWED_LINES'), Hardening.tier1AllowedLines);
      for (final line in Hardening.tier1AllowedLines) {
        final directive = line.split('=').first;
        final advice = RecommendationEngine.getAdvice(directive);
        expect(advice.tier, 1, reason: directive);
        expect(advice.snippet, line, reason: directive);
      }
    });
  });

  group('Hardening.isAllowedTier1Content', () {
    test('accepts generated Tier 1 drop-ins', () {
      expect(
        Hardening.isAllowedTier1Content(
          '[Service]\nNoNewPrivileges=yes\nRestrictRealtime=yes\n',
        ),
        isTrue,
      );
    });

    test('rejects anything else', () {
      expect(
        Hardening.isAllowedTier1Content('[Service]\nExecStartPre=/bin/id\n'),
        isFalse,
      );
      expect(
        Hardening.isAllowedTier1Content('[Unit]\nNoNewPrivileges=yes\n'),
        isFalse,
      );
    });
  });

  group('Hardening.buildDropInContent', () {
    test('emits a [Service] header and real newlines', () {
      final content = Hardening.buildDropInContent([
        HardeningAdvice(
          tier: 1,
          directive: 'NoNewPrivileges',
          humanQuestion: '',
          humanAdvice: '',
          snippet: 'NoNewPrivileges=yes',
        ),
        HardeningAdvice(
          tier: 1,
          directive: 'ProtectKernelTunables',
          humanQuestion: '',
          humanAdvice: '',
          snippet: 'ProtectKernelTunables=yes',
        ),
      ]);
      expect(
        content,
        '[Service]\nNoNewPrivileges=yes\nProtectKernelTunables=yes\n',
      );
      // No literal backslash-n must ever appear (the old %b bug).
      expect(content.contains(r'\n'), isFalse);
    });

    test('preserves % specifiers byte-for-byte', () {
      final content = Hardening.buildDropInContent([
        HardeningAdvice(
          tier: 1,
          directive: 'ReadWritePaths',
          humanQuestion: '',
          humanAdvice: '',
          snippet: 'ReadWritePaths=/run/%t/app',
        ),
      ]);
      // The '%t' must survive intact — this is exactly what printf %b corrupted.
      expect(content.contains('%t'), isTrue);
      expect(content, '[Service]\nReadWritePaths=/run/%t/app\n');
    });
  });

  group('SystemdScanner.parseSecurityList', () {
    test('maps the overview JSON into services', () {
      const json = '''
[
  {"unit":"sshd.service","exposure":"6.6","predicate":"MEDIUM","happy":"🙁"},
  {"unit":"cups.service","exposure":"9.6","predicate":"UNSAFE","happy":"😨"}
]''';
      final services = SystemdScanner.parseSecurityList(json);
      expect(services.length, 2);
      expect(services.first.name, 'sshd.service');
      expect(services.first.exposureScore, 6.6);
      expect(services[1].exposureLevel, 'UNSAFE');
    });

    test('tolerates numeric exposure as well as string', () {
      const json =
          '[{"unit":"a.service","exposure":3.1,"predicate":"OK","happy":"🙂"}]';
      final services = SystemdScanner.parseSecurityList(json);
      expect(services.single.exposureScore, 3.1);
    });
  });

  group('SystemdScanner.parseServiceDetails', () {
    test('returns only unset, exposure-bearing directives', () {
      const json = '''
[
  {"name":"NoNewPrivileges","set":false,"exposure":"0.2","description":"Service may change privileges"},
  {"name":"ProtectHome","set":true,"exposure":"0.3","description":"Already set"},
  {"name":"ZeroExposure","set":false,"exposure":"0.0","description":"No exposure"}
]''';
      final vulns = SystemdScanner.parseServiceDetails(json);
      expect(vulns.length, 1);
      expect(vulns.single.name, 'NoNewPrivileges');
      expect(vulns.single.exposure, 0.2);
    });
  });
}
