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
import 'package:sysdsafe/logging.dart';
import 'package:sysdsafe/paths.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens links, files and mail drafts in the desktop user's own apps.
///
/// SysdSafe runs as root (since 1.0.10). Handing a URL to `xdg-open` from
/// that process would start the browser or mail client as root — a large
/// attack surface, and one that Chromium-based browsers refuse outright.
/// When running as root this launches the opener as the user who started
/// SysdSafe (`PKEXEC_UID`), and refuses rather than fall back to root.
class DesktopLauncher {
  /// Opens [uri] for the desktop user. Returns false if it could not be
  /// opened safely; callers should show the URL or path instead.
  static Future<bool> open(Uri uri) async {
    if (!sysdsafeIsRoot) {
      try {
        return await launchUrl(uri);
      } catch (e) {
        LogService.error('Could not open $uri: $e');
        return false;
      }
    }

    final user = invokingUser();
    if (user == null) {
      LogService.warning(
        'Not opening $uri: running as root and the desktop user is unknown.',
      );
      return false;
    }

    final runtimeDir = '/run/user/${user.uid}';
    final env = <String>[
      'HOME=${user.home}',
      'XDG_RUNTIME_DIR=$runtimeDir',
      'DBUS_SESSION_BUS_ADDRESS=unix:path=$runtimeDir/bus',
      if (Platform.environment['DISPLAY'] != null)
        'DISPLAY=${Platform.environment['DISPLAY']}',
      if (Platform.environment['WAYLAND_DISPLAY'] != null)
        'WAYLAND_DISPLAY=${Platform.environment['WAYLAND_DISPLAY']}',
    ];

    try {
      final result = await Process.run('runuser', [
        '-u',
        user.name,
        '--',
        'env',
        ...env,
        'xdg-open',
        uri.toString(),
      ]);
      if (result.exitCode != 0) {
        LogService.error('xdg-open as ${user.name} failed: ${result.stderr}');
        return false;
      }
      return true;
    } catch (e) {
      LogService.error('Could not open $uri as ${user.name}: $e');
      return false;
    }
  }

  /// A directory the desktop user can read, for files SysdSafe generates for
  /// them to open (e.g. the audit viewer). As root this is
  /// `/run/user/<uid>/sysdsafe`, owned by that user and mode 0700; otherwise
  /// the normal state directory.
  static Future<Directory> userViewableDir() async {
    final user = sysdsafeIsRoot ? invokingUser() : null;
    if (user == null) return sysdsafeStateDir();
    // Never create another user's runtime dir as root; it only exists while
    // that user has a session.
    if (!await Directory('/run/user/${user.uid}').exists()) {
      return sysdsafeStateDir();
    }

    final dir = Directory(p.join('/run/user/${user.uid}', 'sysdsafe'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await Process.run('chown', ['${user.uid}:${user.gid}', dir.path]);
    await Process.run('chmod', ['0700', dir.path]);
    return dir;
  }

  /// Hands ownership of [file] to the desktop user when running as root.
  static Future<void> giveToUser(File file) async {
    final user = sysdsafeIsRoot ? invokingUser() : null;
    if (user == null) return;
    await Process.run('chown', ['${user.uid}:${user.gid}', file.path]);
    await Process.run('chmod', ['0600', file.path]);
  }
}
