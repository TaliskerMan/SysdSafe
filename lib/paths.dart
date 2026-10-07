// Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

import 'dart:io';

import 'package:path/path.dart' as p;

/// System-wide state directory used when SysdSafe runs as root (the normal
/// case since 1.0.10, when the app re-launches itself through pkexec).
const String kSystemStateDir = '/var/lib/sysdsafe';

bool? _isRootCache;

/// Whether this process runs as root (uid 0). Cached after the first call.
bool get sysdsafeIsRoot {
  if (_isRootCache != null) return _isRootCache!;
  var root = false;
  if (Platform.isLinux) {
    try {
      root = Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
    } catch (_) {}
  }
  _isRootCache = root;
  return root;
}

/// Resolves SysdSafe's state directory, creating it if needed.
///
/// - Running as root (installed app): `/var/lib/sysdsafe`, mode 0700. Under
///   pkexec `$HOME` is `/root`, so the old `~/...` paths silently landed in
///   root's home; a fixed system path is predictable and documented.
/// - Otherwise (development, tests): `$XDG_STATE_HOME/sysdsafe`, falling back
///   to `~/.local/state/sysdsafe`.
///
/// Never relative to the working directory, which is undefined for an app
/// launched from the menu.
Future<Directory> sysdsafeStateDir() async {
  final env = Platform.environment;
  if (sysdsafeIsRoot && !env.containsKey('FLUTTER_TEST')) {
    final dir = Directory(kSystemStateDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    try {
      // Backups contain service definitions; keep them root-only.
      await Process.run('chmod', ['0700', dir.path]);
    } catch (_) {}
    return dir;
  }

  var base = env['XDG_STATE_HOME'] ?? '';
  if (base.isEmpty) {
    final home = env['HOME'] ?? '/tmp';
    base = p.join(home, '.local', 'state');
  }
  final dir = Directory(p.join(base, 'sysdsafe'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Directory holding the plain-text `<unit>.backup` copies of each service's
/// original definition (readable from a rescue shell without SysdSafe).
Future<Directory> sysdsafeBackupDir() async {
  final state = await sysdsafeStateDir();
  final dir = Directory(p.join(state.path, 'backups'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// The desktop user who launched SysdSafe through pkexec (or sudo).
class DesktopUser {
  /// Creates a [DesktopUser].
  const DesktopUser({
    required this.name,
    required this.uid,
    required this.gid,
    required this.home,
  });

  /// Login name.
  final String name;

  /// Numeric user id.
  final int uid;

  /// Numeric primary group id.
  final int gid;

  /// Home directory.
  final String home;
}

/// Looks up the user who launched SysdSafe via `PKEXEC_UID` (set by pkexec)
/// or `SUDO_UID`. Returns null when not elevated or the lookup fails.
DesktopUser? invokingUser() {
  final env = Platform.environment;
  final uidText = env['PKEXEC_UID'] ?? env['SUDO_UID'];
  final uid = int.tryParse(uidText ?? '');
  if (uid == null || uid == 0) return null;
  try {
    final result = Process.runSync('getent', ['passwd', '$uid']);
    if (result.exitCode != 0) return null;
    final fields = result.stdout.toString().trim().split(':');
    if (fields.length < 6) return null;
    final gid = int.tryParse(fields[3]);
    if (fields[0].isEmpty || gid == null) return null;
    return DesktopUser(name: fields[0], uid: uid, gid: gid, home: fields[5]);
  } catch (_) {
    return null;
  }
}

/// Home directory of the user who launched SysdSafe, or null.
String? invokingUserHome() => invokingUser()?.home;

/// Folders where versions before 1.0.12 wrote plain-text backups
/// (`~/sysdsafe_backups`): the launching user's home (pre-1.0.10, when the app
/// ran unprivileged) and root's home (1.0.10–1.0.11). The Backups tab reads
/// these so older backups stay visible; nothing is deleted from them.
List<Directory> legacyBackupDirs() {
  final homes = <String>{};
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) homes.add(home);
  final invoking = invokingUserHome();
  if (invoking != null) homes.add(invoking);
  if (sysdsafeIsRoot) homes.add('/root');
  return [for (final h in homes) Directory(p.join(h, 'sysdsafe_backups'))];
}
