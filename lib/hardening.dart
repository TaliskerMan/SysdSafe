// Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

import 'package:sysdsafe/engine/recommendations.dart';

/// Pure helpers for the privileged-hardening path. Kept free of Flutter and
/// I/O so they can be unit-tested directly.
///
/// KEEP IN SYNC with linux/packaging/sysdsafe-helper: [protectedUnitPatterns]
/// must equal the helper's PROTECTED_UNITS and [tier1AllowedLines] its
/// ALLOWED_LINES. test/hardening_test.dart fails if they drift.
class Hardening {
  /// Characters systemd allows in unit names (systemd.unit(5)), including the
  /// backslash used by `systemd-escape`.
  static final RegExp _unitChars = RegExp(r'^[A-Za-z0-9:_.@\\-]+$');

  /// Validates a systemd service name before it is used to build a privileged
  /// file path or passed to systemctl.
  ///
  /// Accepts only `<name>.service` made of systemd's unit-name characters.
  /// Rejects empty names, path separators, parent references and names that
  /// start with `-` (which a command could read as an option).
  static bool isSafeServiceName(String name) {
    if (name.isEmpty || name.length > 255) return false;
    if (name.contains('/') || name.contains('..')) return false;
    if (name.startsWith('-')) return false;
    if (!name.endsWith('.service') || name == '.service') return false;
    return _unitChars.hasMatch(name);
  }

  /// Services where even Tier 1 settings can lock people out or break the
  /// system, so auto-fix is never offered. Glob patterns (`*` = any text)
  /// matched against the unit name WITHOUT its `.service` suffix.
  ///
  /// Why these: services that start user sessions or run programs for users
  /// (sshd, display managers, getty, cron) lose working `sudo` under
  /// NoNewPrivileges; core plumbing (systemd-*, D-Bus, polkit, networking)
  /// can take the machine down; container and VM managers need cgroup access.
  static const List<String> protectedUnitPatterns = [
    'user@*',
    'user-runtime-dir@*',
    '*greeter*',
    'getty@*',
    'serial-getty@*',
    'autovt@*',
    'container-getty@*',
    'console-getty',
    'ssh',
    'sshd',
    'sshd@*',
    'systemd-*',
    'dbus',
    'dbus-broker',
    'polkit',
    'display-manager',
    'gdm',
    'gdm3',
    'sddm',
    'lightdm',
    'lxdm',
    'xdm',
    'accounts-daemon',
    'NetworkManager',
    'networking',
    'wpa_supplicant',
    'cron',
    'crond',
    'anacron',
    'atd',
    'docker',
    'containerd',
    'podman',
    'libvirtd',
    'snapd',
    'cups*',
    'rescue',
    'emergency',
  ];

  /// The only drop-in lines the auto-fix may write (besides `[Service]`).
  /// Must match the Tier 1 snippets in [RecommendationEngine].
  static const List<String> tier1AllowedLines = [
    'NoNewPrivileges=yes',
    'ProtectKernelTunables=yes',
    'ProtectControlGroups=yes',
    'ProtectKernelLogs=yes',
    'RestrictRealtime=yes',
  ];

  static bool _globMatch(String pattern, String text) {
    final regex = RegExp(
      '^${pattern.split('*').map(RegExp.escape).join('.*')}\$',
    );
    return regex.hasMatch(text);
  }

  /// True when auto-fix must not be offered for [serviceName].
  static bool isProtectedService(String serviceName) {
    final stem = serviceName.endsWith('.service')
        ? serviceName.substring(0, serviceName.length - '.service'.length)
        : serviceName;
    return protectedUnitPatterns.any((p) => _globMatch(p, stem));
  }

  /// Builds the systemd drop-in override body from the selected advice.
  ///
  /// Uses REAL newlines (not literal `\n`) so the content can be written
  /// byte-for-byte with `printf '%s'`. This avoids the previous
  /// `printf "%b"` approach, which interpreted backslash escapes and treated
  /// `%` as a format specifier — corrupting any directive containing a `%`
  /// specifier (e.g. `%t`, `%i`) or a backslash.
  static String buildDropInContent(List<HardeningAdvice> advice) {
    final buffer = StringBuffer('[Service]\n');
    for (final item in advice) {
      buffer.writeln(item.snippet);
    }
    return buffer.toString();
  }

  /// True when every line of [content] is `[Service]`, blank, or one of
  /// [tier1AllowedLines] — the same check the root helper enforces.
  static bool isAllowedTier1Content(String content) {
    for (final line in content.split('\n')) {
      if (line.isEmpty || line == '[Service]') continue;
      if (!tier1AllowedLines.contains(line)) return false;
    }
    return true;
  }
}
