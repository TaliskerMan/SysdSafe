# SysdSafe v1.0.15 Official Linux Release

SysdSafe is a graphical security auditing and hardening tool for systemd services on Linux. It leverages systemd's built-in `systemd-analyze security` audit engine, translates complex security directives into plain-language guidance, and applies reversible, sandboxed Tier 1 hardening configurations through drop-in override files.

## What's Changed in v1.0.15
- **Linux Codebase Streamlining:** Removed residual Windows build scaffolding and runtime platform checks, focusing SysdSafe strictly on Linux systemd environments.
- **Dart & Flutter Compatibility:** Adjusted analysis dependency constraints for modern Dart SDK compatibility while maintaining 100% adherence to Very Good Analysis standards.
- **Hardened Release Pipeline:** Updated packaging workflow to generate Syft CycloneDX SBOMs, compute SHA-256 and SHA-512 checksums, and sign releases with Chuck Talk's official maintainer GPG key (`chuck@nordheim.online`).
- **Full Security Audit:** Verified clean test suite (31/31 passing), zero Semgrep SAST issues, and zero dependency CVEs via OSV-Scanner and Grype.

## Package Integrity & Verification

| Asset | Description |
|---|---|
| `sysdsafe_1.0.15_amd64.deb` | Debian/Ubuntu 64-bit installer package |
| `sysdsafe_1.0.15_amd64.deb.asc` | GPG ASCII-armored detached signature |
| `sysdsafe_1.0.15_amd64.deb.sig` | GPG binary detached signature |
| `sysdsafe_1.0.15_amd64.deb.sha512` | SHA-512 checksum |
| `sysdsafe_1.0.15_amd64.deb.sha256` | SHA-256 checksum |
| `pubkey.asc` / `chuck_pubkey.asc` | Maintainer GPG public key (`chuck@nordheim.online`) |
| `SBOM-Linux.json` / `sbom.json` | CycloneDX SBOM (Software Bill of Materials) |
| `security_report.md` | Security and vulnerability scan report |

### Verification Instructions

Import the release signing key and verify the Debian package:
```bash
# Import Chuck Talk's release signing key
gpg --import chuck_pubkey.asc

# Verify the GPG detached signature
gpg --verify sysdsafe_1.0.15_amd64.deb.asc sysdsafe_1.0.15_amd64.deb

# Verify SHA-512 checksum
sha512sum -c sysdsafe_1.0.15_amd64.deb.sha512
```

### Installation
```bash
sudo apt install ./sysdsafe_1.0.15_amd64.deb
```
