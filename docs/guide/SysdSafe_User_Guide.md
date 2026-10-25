title: SysdSafe
subtitle: Installation and User Guide
version: 1.0.14
platforms: Linux (Debian, Ubuntu and derivatives)
## About SysdSafe

SysdSafe helps you audit and harden the **systemd services** on your Linux machine. It reads systemd's own security audit, explains in plain language what each missing protection does, and can apply a small set of low-risk settings for you, always as a separate file you can remove.

Its rule is **"First, do no harm."** systemd runs the services your machine depends on: networking, logins, the desktop and remote access. Hardening them blindly can lock you out or break things. SysdSafe explains before it changes anything, applies only five low-risk settings automatically, refuses to touch services where even those are risky, and keeps every change reversible.

**What SysdSafe does**

- Runs `systemd-analyze security` on all services and shows systemd's exposure levels.
- Explains each missing protection, with advice and a ready-to-use snippet.
- Applies five low-risk ("Tier 1") settings for you, after you review and confirm.
- Backs up each service's definition first, and restores it with one click.
- Includes a reference of systemd directives built from your own system's manual pages.

SysdSafe is free, open-source software under the GNU Affero General Public License v3 (AGPL-3.0). It comes with no warranty. Source: github.com/TaliskerMan/SysdSafe.

## Before you start: the privilege model

> **Important:** SysdSafe **runs as root.** When you open it, it relaunches itself through `pkexec`, which asks for an administrator password. Use it only on machines you administer.

- Changes to services go through a separate, narrow helper, `/usr/lib/sysdsafe/sysdsafe-helper`, which accepts only SysdSafe's own drop-in file for one service at a time.
- So the root app can draw on your screen, the launcher grants the local root user (only) access to your display with `xhost +SI:localuser:root`, and revokes it when SysdSafe exits, is interrupted or is closed.
- Links, the audit report and Email Support open in **your** desktop session as your own user, never as root.

## Safety rules

1. **One service at a time.** Harden one service, test what you use it for, then move on. SysdSafe warns you if you start on a second service before testing the first.
2. **Answer the questions honestly.** Each recommendation asks what the service needs, such as network access or your home folder. A wrong answer is how a hardened service becomes a broken one.
3. **Low risk isn't no risk.** Tier 1 settings suit most standalone services, but not every one. That's why some services are protected.

## Installing SysdSafe

| | |
|---|---|
| Operating system | 64-bit (amd64) Debian, Ubuntu, Pop!_OS or a derivative with systemd |
| Installed with the package | `pandoc` (for the reference), `util-linux`, polkit |
| Recommended | `x11-xserver-utils` (for `xhost`), `xdg-utils`, `fonts-noto-core` |
| Account | An administrator (sudo) account |

Each release includes `sysdsafe_<version>_amd64.deb`, a detached GPG signature (`.sig`), a SHA-512 checksum and the public key (`pubkey.asc`).

```
sha512sum -c sysdsafe_<version>_amd64.deb.sha512
gpg --import pubkey.asc
gpg --verify sysdsafe_<version>_amd64.deb.sig sysdsafe_<version>_amd64.deb
sudo apt install ./sysdsafe_<version>_amd64.deb
```

Open **SysdSafe** from your applications menu and enter your administrator password.

### First run

SysdSafe builds its directive reference from your system's manual pages using `pandoc`. Click **Start Setup** on the **SysdSafe Setup** screen and wait for it to finish.

### Uninstalling

First restore any services you changed (see *Changes & Backups*), then `sudo apt remove sysdsafe`. Its data is in `/var/lib/sysdsafe/`; delete it with `sudo rm -r /var/lib/sysdsafe` if you no longer need the backups.

## Getting around

The bottom bar has five sections: **Dashboard**, **Services**, **Backups**, **Reference** and **Logs**. The toolbar has:

| Button | What it does |
|---|---|
| Open HTML Audit Viewer | Opens the latest audit as a report in your browser |
| Re-scan | Runs the security audit again |
| Font − / + | Text size, up to 19 pt |
| Theme | System default, light or dark (follows your desktop by default) |

Long views have drag scrolling, wide always-visible scrollbars and jump-to-top/bottom buttons. Theme and text size are remembered.

## The audit

SysdSafe runs `systemd-analyze security` and shows each service with systemd's own exposure score and level:

| Level | Meaning (from systemd) |
|---|---|
| UNSAFE | Very few protections set |
| EXPOSED | Many protections missing |
| MEDIUM | Some protections set |
| OK | Well protected |

The **Dashboard** charts how many services are at each level. **Services** lists them; a blue shield marks a protected service. Open a service to see every directive systemd reports as unset, grouped into tiers:

| Tier | Directives | How it's applied |
|---|---|---|
| 1 · Quick wins (low risk) | `NoNewPrivileges`, `ProtectKernelTunables`, `ProtectControlGroups`, `ProtectKernelLogs`, `RestrictRealtime` | Automatically, after you review and confirm (not on protected services) |
| 2 · Contextual (medium risk) | `PrivateNetwork`, `ProtectHome`, `ProtectSystem`, `PrivateTmp`, `RestrictNamespaces` | By you: answer the question, then add the snippet with `sudo systemctl edit <unit>` |
| 3 · Advanced (high risk) | `DynamicUser`, `SystemCallFilter`, `RestrictAddressFamilies` and others | By you only, using the reference |

Each recommendation shows advice and a snippet you can copy with **Copy to Clipboard**.

> **Warning:** `NoNewPrivileges=yes` stops a service, and everything it starts, from gaining privileges through setuid programs. On services that start user sessions or run commands for users (`sshd`, display managers, `cron`), that breaks `sudo` inside those sessions. SysdSafe never auto-applies Tier 1 to those services.

## Applying Tier 1 safely

1. Open a service and review its Tier 1 directives.
2. Click **Confirm & Apply Auto-Fix**. A review dialog lists each directive and its question.
3. SysdSafe backs up the service's current definition. **If the backup fails, nothing is changed.**
4. It writes one file, `/etc/systemd/system/<unit>.d/sysdsafe-tier1.conf`, reloads systemd, and restarts the service only if it was already running.
5. It checks the service immediately and again 20 seconds later. If the service has failed or stopped, you're offered **Revert now**.
6. Test what you use the service for.

Health checks only see whether the service keeps running, not whether every feature still works, and services that depend on it aren't checked. That's why testing yourself matters.

### Protected services

Auto-fix is permanently blocked, in both the app and the root helper, for services where even Tier 1 settings can lock you out or break the system. They show a red **"FIRST DO NO HARM — DO NOT MODIFY"** banner explaining the specific risk. Protected groups include:

- **Remote access and login:** SSH, remote-admin consoles (Webmin, NoMachine), gettys, display managers, user sessions
- **System core and scheduling:** `systemd-*`, D-Bus, polkit, cron, atd, rescue and emergency
- **Networking:** NetworkManager, `systemd-networkd`/`resolved`, `wpa_supplicant`, `networkd-dispatcher`
- **Package management and upgrades:** software-properties, needrestart, unattended-upgrades, Pop!_OS transition
- **Mail, printing and hardware:** Postfix, CUPS, System76 services, thermald, power profiles, TLP, UPower, udisks, LVM, Bluetooth, NVIDIA
- **Diagnostics:** preload, whoopsie, apport, plymouth
- **Containers and virtualisation:** Docker, containerd, Podman, libvirt, VirtualBox, snapd

## Changes & Backups

The **Backups** section lists every service SysdSafe has changed. Filter by **All Records**, **Active Changes** or **Restored / Clean**, and search by name. For each one you can:

- **View Original State**: the definition saved before the change,
- **View Applied Changes**: the drop-in SysdSafe added,
- **Restore to Original State**: removes the drop-in, reloads systemd, restarts the service and reports whether it came back healthy,
- delete the record once a service is back to normal.

### Recovering without SysdSafe

SysdSafe never edits your unit files. From any root shell, including a rescue environment:

```
sudo rm /etc/systemd/system/<unit>.d/sysdsafe-tier1.conf
sudo systemctl daemon-reload
sudo systemctl restart <unit>
```

## Reference and Logs

**Reference** shows systemd directive documentation generated from your own system's manual pages, so it matches your systemd version.

**Logs** shows SysdSafe's log, lets you copy it, and has **Email Support**, which opens a draft to support@nordheim.online with the end of the log. To attach the whole log:

```
sudo cp /var/lib/sysdsafe/app.log ~/ && sudo chown "$USER" ~/app.log
```

## Files and locations

| What | Where |
|---|---|
| Database (backups, settings, reference) | `/var/lib/sysdsafe/sysdsafe.db` |
| Plain-text backups | `/var/lib/sysdsafe/backups/<unit>.backup` |
| Application log | `/var/lib/sysdsafe/app.log` |
| Latest audit (JSON) | `/var/lib/sysdsafe/hardening_audit.json` |
| Audit report for your browser | `/run/user/<your uid>/sysdsafe/audit_viewer.html` |
| Applied changes | `/etc/systemd/system/<unit>.d/sysdsafe-tier1.conf` |

`/var/lib/sysdsafe/` is readable by root only. Backups from versions up to 1.0.11 in `~/sysdsafe_backups/` still appear in the Backups section; they're read, never deleted.

## Troubleshooting

**SysdSafe doesn't open after I enter my password.** Make sure `x11-xserver-utils` is installed (for `xhost`), and try again from a terminal with `sysdsafe` to see messages.

**Setup can't build the reference.** Install `pandoc` (`sudo apt install pandoc`) and click **Start Setup** again.

**A service broke after Auto-Fix.** Use **Revert now**, or **Restore to Original State** in Backups, or the recovery commands above.

**Auto-Fix is greyed out for a service.** It's protected; the red banner explains why. Harden it by hand only if you understand the risk.

**I changed a second service and got a warning.** Test the first service, then continue, or click **Proceed Anyway** if you're sure.

## Support and license

Use **Logs → Email Support**, report problems on GitHub (github.com/TaliskerMan/SysdSafe), or email **support@nordheim.online**. For security issues, see `SECURITY.md` in the repository.

| | |
|---|---|
| Website | nordheim.online |
| Source code | github.com/TaliskerMan/SysdSafe |
| License | GNU AGPL v3 (no warranty) |
| Copyright | © 2026 Chuck Talk, Nordheim Online, LLC |
