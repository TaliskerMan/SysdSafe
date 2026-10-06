# SysdSafe (v1.0.11)

SysdSafe is a graphical systemd service security auditing and hardening tool built with Flutter for Linux workstations and servers.

## Features

- **Systemd Security Auditing:** Performs automated vulnerability and exposure scoring (`systemd-analyze security`) across all active services.
- **Safe Tiered Hardening:** Provides contextual recommendations and automated Tier-1 quick wins written via PolicyKit drop-in overrides.
- **Changes & Backups Restoration Interface:** Tracks all modifications made by the tool, archives pre-fix service snapshots to SQLite and `~/sysdsafe_backups/`, and allows one-click rollback to known original states.
- **Desktop Theme Awareness & Motor Accessibility:** Follows OS appearance settings (Light, Dark, System Default) with high-visibility scrollbars and drag-scrolling support.
- **Shift-Left Security & Verification:** Developed under strict quality gates with CycloneDX SBOM generation and SonarQube quality gate verification.

## Documentation

For full installation instructions, architecture diagrams, and safe rollback guidelines, please see the [User Guide](docs/USER_GUIDE.md).

## Support

If you encounter any issues, SysdSafe features a built-in logging facility and an "Email Support" button to quickly get in touch with our team. Please refer to the User Guide for more details.

## License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
See the [LICENSE](LICENSE) file for the full text.

Source code is available at: https://github.com/TaliskerMan/SysdSafe
