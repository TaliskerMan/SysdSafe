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
    'com.system76.*',
    '*updater*',
    'unattended-upgrades',
    'udisks2*',
    'dm-event*',
    'lvm2-*',
    'vbox*',
    'nvidia*',
    'acpid*',
    'smartmontools*',
    'alsa-state*',
    'fail2ban*',
    'crowdsec*',
    'plymouth*',
    'dmesg*',
    'tpm-udev*',
    'rc-local*',
    'com.ubuntu.SoftwareProperties*',
    '*software-properties*',
    'net.ibh.NeedRestart*',
    '*needrestart*',
    'org.pop_os.transition_system*',
    '*transition_system*',
    '*pop-transition*',
    'networkd-dispatcher*',
    'nxserver*',
    'nxnode*',
    'nxd*',
    'postfix*',
    'preload*',
    'webmin*',
    'whoopsie*',
    'apport*',
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

  /// Returns the specific technical safety reason why [serviceName] is protected
  /// from modification under the "First Do No Harm" principle.
  static String getProtectionReason(String serviceName) {
    final stem = serviceName.endsWith('.service')
        ? serviceName.substring(0, serviceName.length - '.service'.length)
        : serviceName;

    if (_globMatch('ssh*', stem)) {
      return 'OpenSSH server handles remote user sessions. Setting NoNewPrivileges causes sudo and privilege escalation to fail for all SSH users, permanently locking you out of remote administration.';
    }
    if (_globMatch('*greeter*', stem) ||
        _globMatch('display-manager', stem) ||
        _globMatch('gdm*', stem) ||
        _globMatch('sddm*', stem) ||
        _globMatch('lightdm*', stem) ||
        _globMatch('lxdm*', stem) ||
        _globMatch('xdm*', stem)) {
      return 'Display managers and greeters manage graphical user login sessions. Sandboxing prevents PAM authentication and session initialization, preventing you from logging into your desktop.';
    }
    if (_globMatch('getty*', stem) ||
        _globMatch('console-getty', stem) ||
        _globMatch('serial-getty*', stem) ||
        _globMatch('autovt*', stem) ||
        _globMatch('container-getty*', stem)) {
      return 'Virtual console (TTY) login service. Setting NoNewPrivileges breaks sudo on text consoles, eliminating your emergency recovery fallback if the graphical desktop fails.';
    }
    if (_globMatch('cron*', stem) ||
        _globMatch('anacron', stem) ||
        _globMatch('atd', stem)) {
      return 'System task schedulers execute jobs for multiple users. NoNewPrivileges breaks cron tasks that require elevated privileges or setuid binaries.';
    }
    if (_globMatch('cups*', stem)) {
      return 'Printing infrastructure. CUPS printer filters and backends must switch credentials between root and the lp group to access USB and network printer ports. Sandboxing causes print spoolers to fail with "Backend failed" and breaks desktop printing system-wide.';
    }
    if (_globMatch('com.system76.Scheduler*', stem)) {
      return 'System76 Scheduler dynamically tunes kernel CFS parameters and real-time audio/application priorities. Restricting kernel tunables or realtime scheduling causes daemon crashes, audio dropouts, and CPU starvation.';
    }
    if (_globMatch('com.system76.PowerDaemon*', stem)) {
      return 'System76 Power Daemon controls CPU energy performance profiles, charging thresholds, and fan curves. Restricting kernel tunables prevents switching between Battery Life, Balanced, and High Performance power modes.';
    }
    if (_globMatch('com.system76.SystemUpdater*', stem) ||
        _globMatch('*updater*', stem) ||
        _globMatch('unattended-upgrades', stem)) {
      return 'Package and OS update managers execute dpkg and system maintainer scripts requiring root and setuid execution. Sandboxing package managers risks leaving the package database locked and the system in an unbootable, half-updated state.';
    }
    if (_globMatch('udisks2*', stem)) {
      return 'Storage daemon for disk mounting, partition management, and LUKS encryption unlocking. Sandboxing blocks raw block device access and host filesystem mounting, disabling USB flash drive and external drive access in file managers.';
    }
    if (_globMatch('dm-event*', stem) || _globMatch('lvm2-*', stem)) {
      return 'Device-mapper and LVM2 volume monitoring daemons. Sandboxing prevents monitoring thin-pool overflow events, risking catastrophic storage freeze and data loss.';
    }
    if (_globMatch('vbox*', stem)) {
      return 'VirtualBox hypervisor driver and guest services. Requires direct access to kernel module character devices (/dev/vboxdrv*). Sandboxing prevents all virtual machines from starting.';
    }
    if (_globMatch('nvidia*', stem)) {
      return 'NVIDIA GPU driver persistence daemon. Sandboxing breaks access to GPU device nodes (/dev/nvidia*) and halts CUDA/graphics acceleration.';
    }
    if (_globMatch('containerd*', stem) ||
        _globMatch('docker*', stem) ||
        _globMatch('podman*', stem) ||
        _globMatch('libvirtd*', stem)) {
      return 'Container and virtualization runtimes manage cgroups for isolated workloads. ProtectControlGroups prevents creating and managing container resource limits.';
    }
    if (_globMatch('systemd-*', stem)) {
      return 'Core systemd system infrastructure. Custom sandboxing overrides conflict with internal systemd policies and can prevent system boot or login.';
    }
    if (_globMatch('dbus*', stem) || _globMatch('polkit*', stem)) {
      return 'Core system D-Bus messaging and PolicyKit authorization. Sandboxing breaks inter-process communication and privilege elevation dialogs desktop-wide.';
    }
    if (_globMatch('NetworkManager*', stem) ||
        _globMatch('networking*', stem) ||
        _globMatch('wpa_supplicant*', stem)) {
      return 'Core network management stack. Sandboxing cuts network interfaces, Wi-Fi connections, and DNS resolution.';
    }
    if (_globMatch('acpid*', stem)) {
      return 'ACPI event daemon. Sandboxing prevents power button, laptop lid close, and AC adapter event scripts from executing.';
    }
    if (_globMatch('smartmontools*', stem)) {
      return 'SMART hard drive health monitoring daemon. Requires raw ATA/NVMe ioctl device access to detect failing storage drives.';
    }
    if (_globMatch('alsa-state*', stem)) {
      return 'Sound card state daemon. Sandboxing disrupts saving and restoring hardware audio mixer and volume levels.';
    }
    if (_globMatch('fail2ban*', stem) || _globMatch('crowdsec*', stem)) {
      return 'Intrusion prevention service. Modifying kernel tunables or raw sockets can disrupt dynamic firewall packet filtering rules.';
    }
    if (_globMatch('dmesg*', stem) ||
        _globMatch('plymouth*', stem) ||
        _globMatch('tpm-udev*', stem)) {
      return 'Early boot hardware and logging initialization. Sandboxing disrupts boot splash screen, disk encryption password prompts, and kernel ring buffer extraction.';
    }
    if (_globMatch('user@*', stem) ||
        _globMatch('user-runtime-dir@*', stem)) {
      return 'User session broker service. Sandboxing user runtime units breaks desktop environment initialization and all user applications.';
    }
    if (_globMatch('com.ubuntu.SoftwareProperties*', stem) ||
        _globMatch('*software-properties*', stem)) {
      return 'Software and repository management backend. Sandboxing breaks APT keyring updates, PPA additions, and PolicyKit elevation, which can corrupt package management and prevent critical security patches.';
    }
    if (_globMatch('net.ibh.NeedRestart*', stem) ||
        _globMatch('*needrestart*', stem)) {
      return 'Library and daemon restart monitor. Inspects process memory maps in /proc to detect outdated shared libraries after package updates. Sandboxing blinds needrestart to running processes, leaving unpatched security vulnerabilities active.';
    }
    if (_globMatch('org.pop_os.transition_system*', stem) ||
        _globMatch('*transition_system*', stem) ||
        _globMatch('*pop-transition*', stem)) {
      return 'Operating system release and migration manager. Manages distribution upgrades and recovery partition syncs. Sandboxing causes mid-upgrade failures that can leave the system unbootable or lock you out of the desktop shell upon reboot.';
    }
    if (_globMatch('networkd-dispatcher*', stem)) {
      return 'Network state change hook dispatcher. Executes routing, firewall, and DNS hook scripts in /etc/networkd-dispatcher/. Sandboxing causes child hook scripts to inherit NoNewPrivileges, breaking sudo/setuid commands and risking total network connectivity loss upon reboot.';
    }
    if (_globMatch('nxserver*', stem) ||
        _globMatch('nxnode*', stem) ||
        _globMatch('nxd*', stem)) {
      return 'NoMachine remote desktop server. Spawns session helpers with realtime priority and setuid user transitions. Setting RestrictRealtime crashes remote sessions, and NoNewPrivileges terminates remote graphical administration, causing immediate remote lockout.';
    }
    if (_globMatch('postfix*', stem)) {
      return 'Postfix Mail Transport Agent. Uses setgid maildrop binaries (postdrop, postqueue) to place messages in the mail queue. NoNewPrivileges breaks setgid execution, causing all local mail and critical administrative monitoring alerts (cron, smartd, fail2ban) to fail.';
    }
    if (_globMatch('preload*', stem)) {
      return 'Adaptive readahead daemon. SysV-generated service that profiles memory mappings in /proc to prefetch binaries. Sandboxing conflicts with SysV init wrappers and blocks memory profiling.';
    }
    if (_globMatch('webmin*', stem)) {
      return 'Webmin web-based system administration console. Manages user accounts, storage, firewalls, and packages. Sandboxing breaks PAM authentication and system configuration changes, permanently locking administrators out of the web interface.';
    }
    if (_globMatch('whoopsie*', stem) || _globMatch('apport*', stem)) {
      return 'System crash report submission daemon. Reads restricted crash logs and minidumps in /var/crash/ with lock synchronization. Sandboxing disrupts system diagnostic and crash telemetry pipelines.';
    }
    if (_globMatch('rescue*', stem) || _globMatch('emergency*', stem)) {
      return 'Emergency disaster recovery shell. Must maintain unrestricted system privileges to allow recovery of broken installations.';
    }

    return 'This is a protected system service. Modifying its security directives under Tier 1 sandboxing carries a high risk of breaking critical system operations, disabling essential services, or causing authentication lockout.';
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
