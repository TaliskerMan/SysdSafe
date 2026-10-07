# Security Policy

## Supported versions

Only the latest release of SysdSafe receives security fixes. Please upgrade before reporting.

## Reporting a vulnerability

Email **chuck@nordheim.online** with:

- the SysdSafe version (About screen) and your distribution and version,
- what you found and how to reproduce it,
- whether you plan to disclose it publicly, and when.

Please don't open a public GitHub issue for security problems.

## What to expect

SysdSafe is maintained by one person, so these are good-faith targets, not guarantees:

- acknowledgement within 5 business days,
- an initial assessment within 14 days,
- a fix or a written plan for serious issues within 90 days, coordinated with you before public disclosure.

Reporters are credited in the release notes unless they ask not to be.

## Scope

Of particular interest: the privileged helper (`/usr/lib/sysdsafe/sysdsafe-helper`), the polkit policy (`online.nordheim.sysdsafe.*`), the root launcher (`/usr/bin/sysdsafe`), and anything that lets SysdSafe write outside `/etc/systemd/system/<unit>.d/sysdsafe-tier1.conf` or apply settings other than the Tier 1 allowlist.

Out of scope: problems that need an already compromised administrator account, and the effect of hardening settings a user applies by hand.
