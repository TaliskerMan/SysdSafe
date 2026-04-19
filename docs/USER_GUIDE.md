# SysdSafe User Guide

Welcome to SysdSafe! This utility is designed to help you analyze and secure your Linux systemd services. Our goal is to provide a "first, do no harm" approach to system hardening, following the ShadowAgent security principles.

## Table of Contents
1. [Installation](#installation)
2. [Setup & Configuration](#setup--configuration)
3. [Using the Auto-Fix Feature](#using-the-auto-fix-feature)
4. [Safety, Misuse, and Recovery](#safety-misuse-and-recovery)
5. [Logging & Support](#logging--support)

---

## Installation

SysdSafe is distributed as a Debian package (`.deb`). To install it on Debian, Ubuntu, or derivative distributions, run the following command in your terminal:

```bash
sudo dpkg -i sysdsafe_1.0.0_amd64.deb
```

If you encounter missing dependencies, run:
```bash
sudo apt-get install -f
```

---

## Setup & Configuration

Once installed, you can launch SysdSafe from your desktop application menu or by running `sysdsafe` in your terminal. No initial configuration is required. The application immediately reads your system's `systemd` service files to present an analysis of your system's current security posture.

- **Scan Speed**: The initial scan parses your system services and their corresponding manual pages to provide detailed context and mitigation steps. This might take a few seconds depending on the speed of your system.
- **Service Risks**: Services are rated by urgency (High, Medium, Low) based on known risk factors, such as running with root privileges, missing process isolation, or lacking memory protection directives.

---

## Using the Auto-Fix Feature

SysdSafe includes a built-in Auto-Fix engine to help you harden insecure services with ease.

1. **Review Suggestions**: Tap on any service in the list to review the security suggestions (e.g., adding `ProtectSystem=strict`, `PrivateTmp=yes`, etc.).
2. **Apply Auto-Fix**: Tap the "Apply Auto-Fix" button to automatically create a systemd configuration drop-in file (in `/etc/systemd/system/`).
3. **Polkit Authorization**: To apply changes, SysdSafe will prompt you for your user password. SysdSafe executes these operations via `pkexec` ensuring that changes are made securely without requiring the entire app to run as root.

---

## Safety, Misuse, and Recovery

We build with security in mind. Improperly configuring system services can lead to system instability, applications crashing, or the inability to boot your machine.

**Consequences of Misuse:**
- Applying too many restrictions (like `ProtectSystem=strict` or `PrivateNetwork=yes`) to a service that genuinely needs access to system files or the network can cause that service to fail silently or crash upon startup.
- We highly recommend researching specific directives before applying them if you are unsure of their impact.

**SysdSafe Recovery & Revert:**
To ensure your system remains safe, SysdSafe enforces an atomic backup mechanism before making any configuration changes.
- **Backup Location**: Before any Auto-Fix is applied, the original service state is safely backed up to `~/sysdsafe_backups/`. 
- **Reverting Changes**: If a service begins to misbehave after an Auto-Fix, navigate to that service's detail page and tap "Revert Auto-Fix". SysdSafe will remove the custom drop-in file and restore the service to its original configuration.

---

## Logging & Support

SysdSafe utilizes a robust, persistent logging facility to track application events, including when Auto-Fixes and Reverts are applied.

### Accessing Logs
- Logs are stored locally in accordance with the XDG Base Directory Specification: `~/.local/state/sysdsafe/app.log`.
- You can view the logs directly inside the SysdSafe application by navigating to the **Logs** tab via the bottom navigation bar.

### Obtaining Support
If you encounter a problem you cannot recover from, or if you believe you have found a bug, our support team is ready to assist you.
- Open the **Logs** tab in SysdSafe and click the **Email Support** button.
- This will automatically open your default email client with the support address pre-filled (`support@nordheim.online`).
- **Please manually attach the `app.log` file** found at `~/.local/state/sysdsafe/app.log` so our team can help you diagnose the issue.

*Stay safe. Build securely. Do no harm.*
