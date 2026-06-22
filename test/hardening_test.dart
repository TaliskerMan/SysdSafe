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

import 'package:flutter_test/flutter_test.dart';
import 'package:sysdsafe/scanner.dart';
import 'package:sysdsafe/hardening.dart';
import 'package:sysdsafe/engine/recommendations.dart';

void main() {
  group('Hardening.isSafeServiceName', () {
    test('accepts ordinary unit names', () {
      expect(Hardening.isSafeServiceName('sshd.service'), isTrue);
      expect(Hardening.isSafeServiceName('user@1000.service'), isTrue);
    });

    test('rejects empty, path-separator and parent-ref names', () {
      expect(Hardening.isSafeServiceName(''), isFalse);
      expect(Hardening.isSafeServiceName('../etc/passwd'), isFalse);
      expect(Hardening.isSafeServiceName('foo/bar.service'), isFalse);
      expect(Hardening.isSafeServiceName('a..b'), isFalse);
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
      expect(content, '[Service]\nNoNewPrivileges=yes\nProtectKernelTunables=yes\n');
      // No literal backslash-n must ever appear (the old %b bug).
      expect(content.contains('\\n'), isFalse);
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
      const json = '[{"unit":"a.service","exposure":3.1,"predicate":"OK","happy":"🙂"}]';
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
