// Copyright (C) 2026 Chuck Talk <cwtalk1@gmail.com>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

import 'engine/recommendations.dart';

/// Pure helpers for the privileged-hardening path. Kept free of Flutter and
/// I/O so they can be unit-tested directly.
class Hardening {
  /// Validates a systemd unit name before it is used to build a privileged
  /// file path. Rejects empty names and anything containing a path separator
  /// or parent-directory reference, preventing path traversal out of
  /// `/etc/systemd/system/<service>.d/`.
  static bool isSafeServiceName(String name) {
    if (name.isEmpty) return false;
    if (name.contains('/')) return false;
    if (name.contains('..')) return false;
    return true;
  }

  /// Builds the systemd drop-in override body from the selected advice.
  ///
  /// Uses REAL newlines (not literal `\n`) so the content can be written
  /// byte-for-byte with `printf '%s'`/`tee`. This avoids the previous
  /// `printf "%b"` approach, which interpreted backslash escapes and treated
  /// `%` as a format specifier — corrupting any directive containing a `%`
  /// specifier (e.g. `%t`, `%i`) or a backslash.
  static String buildDropInContent(List<HardeningAdvice> advice) {
    final buffer = StringBuffer('[Service]\n');
    for (final a in advice) {
      buffer.writeln(a.snippet);
    }
    return buffer.toString();
  }
}
