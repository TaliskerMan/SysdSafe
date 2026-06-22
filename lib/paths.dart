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
import 'package:path/path.dart' as p;

/// Resolves SysdSafe's per-user state directory.
///
/// Audit output and the generated viewer must NOT be written relative to the
/// current working directory: for an installed `.deb` launched from the app
/// menu the CWD is undefined (often `/` or `$HOME`), which either fails on a
/// read-only CWD or scatters files unpredictably. We follow the XDG Base
/// Directory spec: `$XDG_STATE_HOME/sysdsafe`, falling back to
/// `~/.local/state/sysdsafe`.
Future<Directory> sysdsafeStateDir() async {
  final env = Platform.environment;
  String base = env['XDG_STATE_HOME'] ?? '';
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
