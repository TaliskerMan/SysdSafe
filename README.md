# SysdSafe (v1.0.13)

SysdSafe is a graphical tool for auditing and hardening systemd services on Debian- and Ubuntu-based Linux. It reads systemd's own security audit (`systemd-analyze security`), explains each missing protection in plain language, and can apply a small set of low-risk settings for you as a separate, reversible drop-in file.

## Features

- **Exposure audit:** runs `systemd-analyze security` across all services and groups them by systemd's own exposure levels (UNSAFE, EXPOSED, MEDIUM, OK).
- **Tiered recommendations:** every missing directive is shown as a question with advice and a ready-to-paste snippet. Only Tier 1 (five low-risk settings) can be applied automatically, after you review and confirm. Tier 2 and Tier 3 stay manual.
- **Reversible changes:** SysdSafe never edits a unit file. Its change is one file, `/etc/systemd/system/<unit>.d/sysdsafe-tier1.conf`. The original definition is backed up first, and **Restore** removes the file, reloads systemd and restarts the unit.
- **Changes & Backups tab:** lists every service SysdSafe has touched, shows the original definition and the applied drop-in, and restores with one click.
- **Built-in reference:** directive documentation generated from your system's own man pages (requires `pandoc`).
- **Theme awareness and accessibility:** follows your desktop's light or dark setting, with drag scrolling, wide always-visible scrollbars, jump buttons and scalable text.

## Safeguards: First Do No Harm

- **First Do No Harm:** SysdSafe enforces a strict safety-first approach. Prominent warning banners and unit shield indicators immediately alert users when viewing sensitive or protected services, explaining exactly *why* sandboxing will cause failure or lockout.
- Backup first: if the original definition can't be saved, nothing is changed.
- Review dialog listing each directive before anything is applied; a warning if you change a second service before testing the first.
- **Protected services:** auto-fix is permanently blocked for services where even low-risk settings can lock you out, impair printing, crash container runtimes, or break hardware management. Protected categories include SSH/remote access, display managers, login gettys, cron/atd, systemd core, D-Bus, polkit, NetworkManager, CUPS printing (`cups`, `cups-browsed`, `cupsd`), System76 hardware daemons (`com.system76.*`), power/thermal daemons (`thermald`, `power-profiles-daemon`, `tlp`), storage managers (`udisks2`), and container engines (`docker`, `containerd`, `podman`). The root helper enforces the identical list.
- A narrow root helper that only writes or removes `sysdsafe-tier1.conf` for the named service, and only with the five Tier 1 lines.
- Health checks right after applying and again 20 seconds later, offering **Revert now** if the service failed or stopped.

## Important to know

- **SysdSafe runs as root.** It relaunches itself through `pkexec` and asks for an administrator password. Use it on machines you administer.
- **Low risk is not no risk.** Health checks only see whether a service keeps running, not whether every feature works. Change one service at a time and test it.
- Logs, the database and plain-text backups are kept in **`/var/lib/sysdsafe/`** (root only). Backups made by earlier versions in `~/sysdsafe_backups/` still appear in the Backups tab.
- Links (About, audit report, Email Support) open in your own desktop session, never as root.

## Documentation

Installation, the privilege model, recovery steps and the full safeguard list are in the [User Guide](docs/USER_GUIDE.md).

## Support

The **Logs** tab has an **Email Support** button (support@nordheim.online). To report a security problem, see [SECURITY.md](SECURITY.md).

## License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See the [LICENSE](LICENSE) file for the full text. It comes with no warranty.

Source code: https://github.com/TaliskerMan/SysdSafe
