// Copyright (C) 2026 Chuck Talk <cwtalk1@gmail.com>
// This file is part of SysdSafe.
//
// SysdSafe is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, version 3.
//
// SysdSafe is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY. See the GNU AGPL v3 for details.

class HardeningAdvice {
  final int tier; // 1 = Low Risk, 2 = Medium Risk, 3 = High Risk
  final String directive;
  final String humanQuestion;
  final String humanAdvice;
  final String snippet;

  HardeningAdvice({
    required this.tier,
    required this.directive,
    required this.humanQuestion,
    required this.humanAdvice,
    required this.snippet,
  });
}

/// Documentation for RecommendationEngine.
class RecommendationEngine {
  static final Map<String, HardeningAdvice> _matrix = {
    // TIER 1: Low Risk (Quick Wins)
    'NoNewPrivileges': HardeningAdvice(
      tier: 1,
      directive: 'NoNewPrivileges',
      humanQuestion: 'Is this service safe to prevent from escalating privileges?',
      humanAdvice: 'Almost universally safe. Ensures the service processes cannot gain new privileges through setuid/setgid.',
      snippet: 'NoNewPrivileges=yes',
    ),
    'ProtectKernelTunables': HardeningAdvice(
      tier: 1,
      directive: 'ProtectKernelTunables',
      humanQuestion: 'Can we restrict modifications to kernel variables?',
      humanAdvice: 'Safe for 99% of services. Prevents altering sysctl or kernel variables.',
      snippet: 'ProtectKernelTunables=yes',
    ),
    'ProtectControlGroups': HardeningAdvice(
      tier: 1,
      directive: 'ProtectControlGroups',
      humanQuestion: 'Can we lock down cgroups access?',
      humanAdvice: 'Safe for most services unless it is a container manager like Docker.',
      snippet: 'ProtectControlGroups=yes',
    ),
    'ProtectKernelLogs': HardeningAdvice(
      tier: 1,
      directive: 'ProtectKernelLogs',
      humanQuestion: 'Can we deny access to the kernel ring buffer (dmesg)?',
      humanAdvice: 'Safe for almost all services. Prevents reading kernel logs.',
      snippet: 'ProtectKernelLogs=yes',
    ),
    'RestrictRealtime': HardeningAdvice(
      tier: 1,
      directive: 'RestrictRealtime',
      humanQuestion: 'Can we deny real-time scheduling?',
      humanAdvice: 'Safe for most services except specific audio or extreme low-latency apps.',
      snippet: 'RestrictRealtime=yes',
    ),

    // TIER 2: Medium Risk (Contextual)
    'PrivateNetwork': HardeningAdvice(
      tier: 2,
      directive: 'PrivateNetwork',
      humanQuestion: 'Does this service need to connect to the internet or local network?',
      humanAdvice: 'If NO: Apply this immediately. It completely isolates the service from the network. (Do NOT apply to network services like nginx, sshd).',
      snippet: 'PrivateNetwork=yes',
    ),
    'ProtectHome': HardeningAdvice(
      tier: 2,
      directive: 'ProtectHome',
      humanQuestion: 'Does this service need to read or write to user home directories?',
      humanAdvice: 'If NO: Apply this. It makes /home and /root inaccessible. Very important for stopping data exfiltration.',
      snippet: 'ProtectHome=yes',
    ),
    'ProtectSystem': HardeningAdvice(
      tier: 2,
      directive: 'ProtectSystem',
      humanQuestion: 'Does this service need to modify system files in /usr or /etc?',
      humanAdvice: 'If NO: Apply this. It mounts /usr and /boot (and /etc if set to "strict") read-only.',
      snippet: 'ProtectSystem=strict',
    ),
    'PrivateTmp': HardeningAdvice(
      tier: 2,
      directive: 'PrivateTmp',
      humanQuestion: 'Can this service use its own isolated /tmp folder?',
      humanAdvice: 'If YES: Apply this. Prevents the service from seeing or tampering with temporary files of other users/services.',
      snippet: 'PrivateTmp=yes',
    ),
    'RestrictNamespaces': HardeningAdvice(
      tier: 2,
      directive: 'RestrictNamespaces',
      humanQuestion: 'Does this service spawn containers or complex namespaces?',
      humanAdvice: 'If NO: Apply this. It prevents the service from creating new Linux namespaces.',
      snippet: 'RestrictNamespaces=yes',
    ),

    // TIER 3: High Risk (Advanced)
    'DynamicUser': HardeningAdvice(
      tier: 3,
      directive: 'DynamicUser',
      humanQuestion: 'Can this service run as a transient, non-root user?',
      humanAdvice: 'Warning: This dynamically allocates a user. Files created will be owned by this dynamic user, which might complicate file sharing. Excellent for stateless daemons.',
      snippet: 'DynamicUser=yes',
    ),
    'SystemCallFilter': HardeningAdvice(
      tier: 3,
      directive: 'SystemCallFilter',
      humanQuestion: 'Can we restrict the system calls this service makes?',
      humanAdvice: 'Warning: This requires knowing exactly what syscalls the app needs. Blocking @clock, @module, or @mount is generally safe for non-system tools.',
      snippet: 'SystemCallFilter=~@clock @module @mount @reboot @swap',
    ),
    'RestrictAddressFamilies': HardeningAdvice(
      tier: 3,
      directive: 'RestrictAddressFamilies',
      humanQuestion: 'Can we block exotic network protocols?',
      humanAdvice: 'Warning: Typically you only want to allow AF_UNIX, AF_INET, and AF_INET6. Blocking others reduces kernel attack surface.',
      snippet: 'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6',
    ),
  };

  /// Documentation for getAdvice.
  static HardeningAdvice getAdvice(String directiveRaw) {
    // directiveRaw from JSON might look like "ProtectHome=" or "CapabilityBoundingSet=~CAP_SYS_TIME"
    final baseDirective = directiveRaw.split('=')[0];

    return _matrix[baseDirective] ?? HardeningAdvice(
      tier: 3,
      directive: baseDirective,
      humanQuestion: 'Should we restrict the system access controlled by $baseDirective?',
      humanAdvice: 'We do not have simple advice for this directive. It is an advanced feature. Please check the Systemd Reference for detailed documentation.',
      snippet: '\$baseDirective=...',
    );
  }
}
