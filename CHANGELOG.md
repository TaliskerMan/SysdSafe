# Changelog — SysdSafe

All notable changes to the SysdSafe project are documented in this file. This project adheres to Semantic Versioning.

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
