# SysdSafe — User Guide

SysdSafe is a graphical assistant for auditing and hardening systemd services on Debian- and Ubuntu-based Linux.

Its core philosophy is **"First, do no harm."** systemd runs the services your machine depends on: networking, logins, the desktop, remote access. Hardening them blindly can lock you out or break the system. SysdSafe helps you understand what each protection does, applies only a small set of low-risk settings for you, and keeps every change reversible.

> [!IMPORTANT]
> **Privilege model (since 1.0.10)**
> SysdSafe **runs as root**. When you start it from the menu, `/usr/bin/sysdsafe` relaunches it through `pkexec` (polkit action `online.nordheim.sysdsafe.gui`), which asks for an administrator password. If you start the binary directly without root, it relaunches itself the same way. Changes to services go through a separate, narrow root helper, `/usr/lib/sysdsafe/sysdsafe-helper` (polkit action `online.nordheim.sysdsafe.manage-service`). Use SysdSafe on machines you administer.
>
> To let the root app draw on your display, the launcher grants the local root user (only) access with `xhost +SI:localuser:root`. It revokes that grant when SysdSafe exits, is interrupted or is terminated.

---

## 1. Safety rules

1. **One service at a time.** Harden one service, restart it, test what you use it for, then move on. SysdSafe warns you if you start on a second service before testing the first.
2. **Answer the questions honestly.** Each recommendation asks what the service needs, for example network access or home folders. A wrong answer is how a hardened service becomes a broken one.
3. **Low risk is not no risk.** Tier 1 settings are safe for most standalone daemons, but not for every service. That's why some services are protected (section 4).

---

## 2. How the audit works

SysdSafe runs `systemd-analyze security` and shows the result. Each service gets systemd's own exposure score and level:

| Level | Meaning (from systemd) |
| :--- | :--- |
| UNSAFE | Very few protections set |
| EXPOSED | Many protections missing |
| MEDIUM | Some protections set |
| OK | Well protected |

Open a service to see each directive systemd reports as **unset**, sorted into tiers:

| Tier | Directives | How it's applied |
| :--- | :--- | :--- |
| 1 · Quick wins (low risk) | `NoNewPrivileges`, `ProtectKernelTunables`, `ProtectControlGroups`, `ProtectKernelLogs`, `RestrictRealtime` | Auto-fix after you review and confirm, unless the service is protected |
| 2 · Contextual (medium risk) | `PrivateNetwork`, `ProtectHome`, `ProtectSystem`, `PrivateTmp`, `RestrictNamespaces` | Manual: answer the question, then add the snippet with `sudo systemctl edit <unit>` |
| 3 · Advanced (high risk) | `DynamicUser`, `SystemCallFilter`, `RestrictAddressFamilies` and any other directive | Manual only, with the reference docs |

> [!WARNING]
> `NoNewPrivileges=yes` stops a service **and everything it starts** from gaining privileges through setuid programs. On services that start user sessions or run commands for users (`sshd`, display managers, `cron`), that breaks `sudo` inside those sessions. SysdSafe never auto-applies Tier 1 to those services.

---

## 3. Installation

SysdSafe is distributed as a Debian package with a detached GPG signature.

```bash
# Verify the package
gpg --import pubkey.asc
gpg --verify sysdsafe_<version>_amd64.deb.sig sysdsafe_<version>_amd64.deb

# Install (pulls in pandoc and the other dependencies)
sudo apt install ./sysdsafe_<version>_amd64.deb
```

On first launch, SysdSafe builds its directive reference from your system's man pages with `pandoc`.

---

## 4. Safeguards

### Before a change

- **Backup or nothing.** SysdSafe saves the current definition (`systemctl cat <unit>`) to its database and to `/var/lib/sysdsafe/backups/<unit>.backup`. If the backup fails, nothing is changed.
- **Review dialog.** Every directive to be added is listed with its question before you confirm.
- **One service at a time.** You get a warning if you change a second service before testing the first. You can override it.
- **Protected services (First Do No Harm).** Auto-fix is permanently disabled, accompanied by an unmistakable red **"FIRST DO NO HARM — DO NOT MODIFY"** warning banner explaining the exact operational hazard (lockout, broken hardware controls, lost printing, or kernel sync failures). The protected list is matched against unit names without `.service`:
  - Remote access & login: `ssh`, `sshd`, `sshd@*`, `getty@*`, `serial-getty@*`, `autovt@*`, `container-getty@*`, `console-getty`, `user@*`, `user-runtime-dir@*`, `*greeter*`, `display-manager`, `gdm`, `gdm3`, `sddm`, `lightdm`, `lxdm`, `xdm`, `accounts-daemon`
  - System core & scheduling: `systemd-*`, `dbus`, `dbus-broker`, `polkit`, `cron`, `crond`, `anacron`, `atd`, `rescue`, `emergency`
  - Networking & resolution: `NetworkManager`, `NetworkManager-wait-online`, `networking`, `wpa_supplicant`, `systemd-resolved`, `systemd-networkd`
  - Printing & imaging: `cups`, `cups-browsed`, `cupsd`
  - Hardware management & power: `com.system76.*`, `thermald`, `power-profiles-daemon`, `tlp`, `upower`, `udisks2`, `bluetooth`
  - Container runtimes & hypervisors: `docker`, `containerd`, `podman`, `libvirtd`, `snapd`
- **Checked names.** Only `<name>.service` names made of systemd's unit-name characters are accepted. Names are always passed after `--` so they can't be read as options.

### During the change

- The root helper only accepts the drop-in path `/etc/systemd/system/<unit>.d/sysdsafe-tier1.conf` for the **same** unit it restarts. It refuses protected units, and it rejects any content other than `[Service]` and the five Tier 1 lines.
- The file is written to a temporary name and renamed into place, byte for byte.
- `systemctl try-restart` restarts the service only if it was already running.

### After the change

- **Health checks.** If the service was running, SysdSafe checks it immediately and again 20 seconds later. If it has failed or stopped, you're offered **Revert now**. These checks only see whether the service keeps running, not whether every feature still works, so test what you rely on.
- **Changes & Backups tab.** Lists every service SysdSafe has touched, with the original definition and the applied drop-in. **Restore to Original State** removes the drop-in, reloads systemd, restarts the unit and reports whether it came back healthy. You can prune records for services that are back to normal.

### Recovering without SysdSafe

SysdSafe never edits your unit files. From any root shell, including a rescue environment:

```bash
sudo rm /etc/systemd/system/<unit>.d/sysdsafe-tier1.conf
sudo systemctl daemon-reload
sudo systemctl restart <unit>
```

---

## 5. Files and logs

Because SysdSafe runs as root, it keeps its files in a root-only folder:

| What | Where |
| :--- | :--- |
| Database (backups, settings, directive reference) | `/var/lib/sysdsafe/sysdsafe.db` |
| Plain-text backups | `/var/lib/sysdsafe/backups/<unit>.backup` |
| Application log | `/var/lib/sysdsafe/app.log` |
| Latest audit (JSON) | `/var/lib/sysdsafe/hardening_audit.json` |
| Audit report opened in your browser | `/run/user/<your uid>/sysdsafe/audit_viewer.html` |

Upgrading from an earlier version:

- **1.0.10–1.0.11:** the database is copied from root's application-support folder on first start.
- **Up to 1.0.11:** plain-text backups in `~/sysdsafe_backups/`, in your home folder or in `/root`, still appear in the Backups tab. They are read, never deleted.

Links in the app (About, the audit report, Email Support) open in **your** desktop session as your user, never as root. If SysdSafe can't tell who you are, it shows the link or path instead of opening it.

### Support

The **Logs** tab shows the log and has **Email Support**, which opens a draft to support@nordheim.online with the end of the log. To attach the full log or a backup:

```bash
sudo cp /var/lib/sysdsafe/app.log ~/ && sudo chown "$USER" ~/app.log
```

---

## 6. Technical stack

| Component | Library / Dependency | Role |
| :--- | :--- | :--- |
| GUI | Flutter SDK & Dart | Desktop interface |
| Charts | `fl_chart` | Exposure distribution chart |
| Storage | `sqflite_common_ffi`, `sqlite3` | Backups, settings, directive reference |
| Reference rendering | `flutter_markdown_plus`, `pandoc` | Man pages rendered in the app |
| Links | `url_launcher`, `xdg-open` via `runuser` | Opening links as the desktop user |
| Privilege | polkit (`pkexec`) | Admin authentication |

The interface uses the system's Noto Sans font (package `fonts-noto-core`) or falls back to the default font. No fonts are downloaded at runtime.

---

## 7. Theme and accessibility

- **System Default / Light / Dark**, via the theme button in the toolbar. System Default follows your desktop (Freedesktop portal `org.freedesktop.appearance.color-scheme`).
- **Drag scrolling** with mouse, trackpad or stylus, for anyone who finds a mouse wheel hard to use.
- **Wide, always-visible scrollbars** (14 px).
- **Jump to top / bottom** buttons on long views.
- **Text size** (+/- in the toolbar) up to 19 pt without clipping.
- Theme and text size are remembered between sessions.

---

## 8. Release and packaging

`scripts/package_deb.sh` reads the version from `pubspec.yaml`, builds the Flutter Linux release, and assembles the `.deb`:

- `/opt/sysdsafe/` — the application
- `/usr/bin/sysdsafe` — the root launcher (pkexec, display grant with automatic revoke)
- `/usr/lib/sysdsafe/sysdsafe-helper` — the root helper (root:root, 0755)
- `/usr/share/polkit-1/actions/online.nordheim.sysdsafe.policy` — the two polkit actions

`scripts/publish_release.sh` writes a SHA-512 checksum, exports the public key (`pubkey.asc`), makes a detached GPG signature with key `1779CD0F50DBB64C187908264863C73517D810F8`, and publishes the release on GitHub.

### Release deliverables

- `sysdsafe_<version>_amd64.deb`
- `sysdsafe_<version>_amd64.deb.sig` (detached signature)
- `sysdsafe_<version>_amd64.deb.sha512`
- `pubkey.asc`

---

*SysdSafe is open-source software under the GNU Affero General Public License v3.0 (AGPL-3.0). It comes with no warranty.*
