# Changelog — SysdSafe

All notable changes to the SysdSafe project are documented in this file. This project adheres to Semantic Versioning.

---

## [1.0.11] - 2026-10-06

### Added
- **Changes & Backups Restoration Interface:** Introduced a dedicated `Backups` navigation tab and `BackupsScreen` allowing users to see all modifications made by SysdSafe, inspect backed-up original unit files, and view active hardening drop-ins.
- **Clean State Rollback:** Enabled one-click "Restore to Original State" functionality to undo hardening changes, remove override drop-ins, and safely reload and restart systemd services.
- **Real-Time Override Tracking:** Implemented automated cross-referencing between SQLite `backups` records, local `~/sysdsafe_backups/` files, and active `/etc/systemd/system/*.d/sysdsafe-tier1.conf` overrides.
- **Search & Filter Controls:** Added dynamic text filtering and status filtering (`All Records`, `Active Changes`, `Restored / Clean`) alongside jump-to-top and jump-to-bottom scroll controls.

---

## [1.0.10] - 2026-10-05

### Added
- **Privileged Launch Enforcement:** Guaranteed SysdSafe only runs with elevated administrative (root) privileges. If launched unprivileged, it automatically re-executes via `pkexec` / `/usr/bin/sysdsafe`.
- **PolicyKit GUI Action (`online.nordheim.sysdsafe.gui`):** Registered dedicated Polkit action in `online.nordheim.sysdsafe.policy` with `org.freedesktop.policykit.exec.allow_gui = true` for `/opt/sysdsafe/sysdsafe`.
- **X11 / Wayland Display Access Handling:** Added automatic `xhost +SI:localuser:root` forwarding in the `/usr/bin/sysdsafe` launcher wrapper to ensure the root-elevated Flutter GUI can seamlessly connect to user display servers without GTK display errors.
- **Root Helper Direct Execution:** Updated `_runPrivileged` in `ServiceDetailScreen` to execute hardening commands directly when already running as root, eliminating redundant elevation prompts.

---

## [1.0.9] - 2026-10-05

### Added
- **Desktop Theme Awareness:** Integrated Material 3 with `ColorScheme.fromSeed`, real-time Freedesktop Portal DBus theme tracking, and an AppBar 3-way theme selector (`System Default`, `Light Theme`, `Dark Theme`).
- **Persistent Preferences:** Added automatic SQLite storage for theme mode and font size selections so user settings survive restarts.
- **Accessible Drag Scrolling:** Enabled pointer/mouse, trackpad, and stylus drag scrolling globally across all views via `AccessibleDesktopScrollBehavior` for users with motor difficulties.
- **High-Visibility Scrollbars:** Configured 14px thick, always-visible scrollbars with high contrast across light and dark themes.
- **Jump-to-Top / Jump-to-Bottom Navigation:** Added dedicated scroll jump buttons to Service List, Security Reference, Service Detail, and Application Logs screens.

### Fixed
- **Layout Overflows on Font Scaling:** Replaced rigid static containers in `DashboardScreen` and `PageContainer` (`AboutScreen`) with scrollable views, preventing content clipping when font size is increased up to 19pt.
- **Database Resilience:** Added automatic table migrations on database open for `directives`, `backups`, and `app_settings` to prevent missing table exceptions on pre-existing installations.
- **Scrollbar Scheduler Assertions:** Resolved missing ScrollPosition assertions by removing unattached scrollbar wrappers and properly binding controllers.

---

## [1.0.5] - 2026-06-22

### Fixed
- **Byte-exact drop-in writes (P0):** Replaced `printf "%b"` with `printf '%s'`
  (and real newlines) when writing override configs. `%b` interpreted backslash
  escapes and treated `%` as a format specifier, which would silently corrupt
  any directive containing a `%` specifier (e.g. `%t`, `%i`) or a backslash.
- **Audit file location:** `hardening_audit.json` and the generated viewer now
  write to `$XDG_STATE_HOME/sysdsafe` (`~/.local/state/sysdsafe`) instead of a
  path relative to the current working directory, which was undefined for an
  installed `.deb` launched from the menu.

### Added
- **Named Polkit action:** Apply/revert now run through a root helper
  (`/usr/lib/sysdsafe/sysdsafe-helper`) bound to the
  `online.nordheim.sysdsafe.manage-service` Polkit action, giving users a clear
  authorization prompt instead of an opaque "sh wants to run as root". A
  development fallback keeps `flutter run` working without installation.
- **Post-apply health check:** After hardening a running service, SysdSafe
  checks `is-active`/`is-failed` and proactively offers one-click revert if the
  service degraded.
- **Unit tests:** Coverage for `systemd-analyze` JSON parsing, service-name
  validation, and drop-in content generation.

### Changed
- **Version is now single-sourced from `pubspec.yaml`** (1.0.5). `package_deb.sh`
  no longer auto-increments `scripts/.version`, ending the version drift across
  pubspec / `.version` / tag / `.deb`.
- Repo hygiene: removed committed release artifacts and a stray `test.cpp`;
  release artifacts now belong in GitHub Releases.

---

## [1.0.2] - 2026-06-09

### Added
- **GPG Release Signing:** Integrated automatic GPG detached-signing (`.deb.sig`) using key fingerprint `1779CD0F50DBB64C187908264863C73517D810F8`.
- **Public Key Validation:** Exported public key `pubkey.asc` to release targets to let users manually verify package signatures.
- **SHA512 Checksums:** Added automated SHA512 hash generation for the built Debian packages.
- **GitHub Release Automation:** Integrated `publish_release.sh` using GitHub CLI (`gh`) to upload the `.deb`, signatures, hashes, public keys, and the updated User Guide.

---

## [1.0.1] - 2026-05-15

### Added
- **Privilege Escalation Controls:** Integrated Polkit `pkexec` wrappers to execute systemd drop-in override writes as root, leaving the GUI unprivileged.
- **Atomic Backup Engine:** Added automatic backup of original configuration files under `~/sysdsafe_backups/` before any settings modification.
- **Surgical Rollback Revert:** Added a "Revert Auto-Fix" button to instantly restore backed-up configurations and remove Custom Drop-ins.

---

## [1.0.0] - 2026-04-10

### Added
- **Urgency Risk Auditing:** Scan and categorize local systemd services into High, Medium, and Low risk buckets based on running privilege and sandbox state.
- **Service Configuration Parser:** Added interactive detail panel showing configuration blocks and custom service parameters.
- **Inline Man Page Reader:** Embed system manual page descriptions to explain what hardening directives actually do.
- **Local Application Log:** Persistent log tracking to `~/.local/state/sysdsafe/app.log` with support for direct email forwarding.
