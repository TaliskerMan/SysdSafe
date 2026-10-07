# SysdSafe: Safer systemd Hardening — Speaker Script

TAM briefing · v1.0.12 · Chuck Talk · 13 slides

Total speaking time: about 12 minutes, plus questions.

Each section matches one slide. Timings are approximate. **Before presenting, fill in the bracketed results on slide 12 (Proof)** from the 1.0.12 release run.

## 1. SysdSafe: systemd hardening without breaking the host
*~40 seconds*

Thanks for the time. I'm Chuck Talk, and in the next twelve minutes I'll walk you through SysdSafe, a Linux desktop tool I build and ship under Nordheim Online. SysdSafe helps an administrator find out how exposed their systemd services are, understand what each hardening setting does, and apply the low-risk ones in a way that can always be undone. I'll cover what it is, what it recommends, how you use it, and then spend real time on the safeguards, including where they stop, because with a tool that changes how system services run, the guard rails matter as much as the features.

## 2. Most services run with far more access than they need
*~55 seconds*

Here's the problem. systemd runs nearly every background service on a modern Linux machine, and unless a unit file opts in to restrictions, a service gets broad access: it can read home folders, touch kernel settings, and talk to the network. systemd ships a good auditing tool, systemd-analyze security, which scores every unit, but its output is a wall of directive names that most people can't act on. And the danger runs the other way too: harden the wrong service with the wrong setting and you can lose networking, your login screen, or remote access. SysdSafe sits in the middle. It turns that audit into plain-language questions and advice, and it makes the changes it applies reversible.

## 3. A graphical front end for systemd's own security audit
*~60 seconds*

SysdSafe is a desktop app for Debian- and Ubuntu-based Linux, and it works in five steps. It scans: it runs systemd-analyze security across every unit on the machine. It prioritizes: a dashboard groups services by systemd's own exposure levels, UNSAFE, EXPOSED, MEDIUM and OK. It helps you understand: open a service and every missing protection is shown as a plain question, like 'does this service need to reach the network?', with advice and the matching text pulled from your own system's man pages. It applies: the low-risk quick wins can be written for you as a separate drop-in file. And it restores: every change is tracked, and one click puts the service back. A point I'd stress to a customer: the scores come straight from systemd, not from a private formula, so anything SysdSafe tells you, an admin can verify from a terminal.

## 4. Three tiers, and only the first is ever automated
*~60 seconds*

The heart of SysdSafe is a recommendation engine that sorts every missing directive into three tiers. Tier one, the quick wins, are five settings that are low risk for most services, things like NoNewPrivileges and ProtectKernelTunables. These are the only ones SysdSafe will ever apply for you, only after you've reviewed the list and confirmed, and never on the protected services I'll show you shortly, like sshd or a display manager. Tier two is contextual: settings like PrivateNetwork or ProtectHome that are excellent if the service doesn't need the network or home folders, and break it if it does. SysdSafe asks you that question and gives you the snippet, but you make the change. Tier three is advanced, such as system call filters and dynamic users, plus any directive SysdSafe doesn't have specific advice for; that's manual only, with a warning and the reference docs. The design principle is simple: the more a setting depends on knowing the service, the more the decision stays with a human.

## 5. Read with systemd, write one file, never touch the original
*~65 seconds*

Here's what happens under the hood. SysdSafe reads with systemd's own tool, systemd-analyze, which gives it each unit's exposure score and the list of protections that aren't set. Scanning and reading advice change nothing on the system. When you do apply quick wins, SysdSafe first takes a backup, then hands the work to a small root helper, sysdsafe-helper, registered as its own polkit action. That helper does exactly two things: write one drop-in file, named sysdsafe-tier1.conf, in the service's override folder, or remove it, then reload systemd and restart the unit. The man pages on your machine are converted with pandoc into the in-app reference, and backups go into a local SQLite database plus a plain-text copy. The most important design point is in yellow: SysdSafe never edits your original unit file. Its change is always a separate drop-in, so restoring means deleting that one file. One more thing to be upfront about: since version 1.0.10 the whole app runs as root after you authenticate through polkit, so it's a tool for administrators on machines they own.

## 6. From install to first hardened service
*~60 seconds*

Using it takes four steps. First, install and verify: every release ships with a detached GPG signature and the public key, and those commands at the bottom are the whole check. apt also pulls in pandoc, which SysdSafe uses to turn your man pages into its reference library. Second, launch it. You'll get a polkit prompt for administrator authentication, and on first run SysdSafe reads your system's man pages to build its directive reference. Third, pick one service, usually one of the UNSAFE ones on the dashboard, and read through the questions. Answer them honestly; they're the difference between a hardened service and a broken one. Fourth, apply the quick wins, then actually test the service, and either keep the change or restore it from the Backups tab. The rule SysdSafe keeps repeating, and that I'd repeat to any customer: one service at a time.

## 7. Nothing changes until it's backed up and confirmed
*~65 seconds*

Now the safeguards, starting with everything that happens before a single setting changes. First, backup or nothing: SysdSafe captures the service's current definition with systemctl cat and saves it to its database and to a plain-text file. If that backup fails for any reason, the change is cancelled. Second, you see every line: a review dialog lists each directive it's about to add, with the question behind it, and nothing happens until you confirm. Third, one service at a time: if you've just changed one service and try to harden another before testing, SysdSafe stops you with a warning. You can override it, but you have to choose to. Fourth, protected services: for services where even low-risk settings can lock you out, auto-fix is switched off entirely and a critical warning explains why. That list covers sshd, display managers, getty, cron, all of systemd's own services, D-Bus, polkit, networking and container managers, and the root helper enforces the same list, so the app can't be talked around it. Fifth, it only proposes Tier-one settings that systemd itself reports as missing. And sixth, inputs are checked: a unit name with a slash or a double dot is rejected, and names are always passed so they can't be mistaken for command options.

## 8. Every change can be seen and undone
*~65 seconds*

Then during and after the change. The write is done by the narrow root helper I mentioned. It only accepts the sysdsafe-tier1.conf file for the same service it restarts, it refuses protected services, and it rejects any content except the five Tier one lines, so even a bug in the app can't make it write anything else. It writes to a temporary file and renames it into place, byte for byte; an early version mangled percent signs, which was caught in review and fixed in 1.0.5. It restarts with try-restart, so a service that wasn't running stays stopped. Right after applying, and again twenty seconds later, SysdSafe checks whether a service that was running has failed or stopped, and if so it puts a Revert now button in front of you. Later, the Backups tab lists every service SysdSafe has touched, shows the original definition and exactly what was added, and offers Restore to original state, which removes the drop-in, reloads systemd, restarts the unit and reports whether it came back healthy. And if the app itself won't start, recovery doesn't depend on it: delete that one drop-in file from any shell, even a rescue environment, and the service is back to how it was.

## 9. Where the safeguards stop
*~65 seconds*

I'd show this slide to every customer, because trust comes from knowing the edges. First, low risk is not no risk. In 1.0.12 the protected list keeps auto-fix away from the services where we know Tier one can lock people out, like sshd and display managers, but a service that isn't on that list can still depend on something Tier one takes away. Second, the health window is short: SysdSafe checks right away and again after twenty seconds, which tells you the service is running, not that every feature works, so test what matters to you. Third, it checks only the service you changed, not the ones that depend on it; that's on the roadmap. Fourth, the whole app runs as root after you authenticate, so it belongs on machines you administer; links and reports open as your own user, never as root. Fifth, Tier two and three changes you make by hand aren't tracked by the Backups tab. And sixth, it's packaged for Debian and Ubuntu, and it keeps its log, database and backups in a root-only folder, /var/lib/sysdsafe.

## 10. Built for the people who use it every day
*~55 seconds*

Beyond hardening itself, a few features make SysdSafe practical day to day. The dashboard charts how many services fall into each exposure level, so you can see progress as you work through them. The reference library is built from the man pages already on your machine, so it matches your systemd version and works offline. The Backups tab lets you search and filter every change, restore a service, and prune old records once a service is back to normal. Every scan, fix and revert is logged, and the Logs tab has an Email Support button. It follows your desktop's light or dark theme, or you can pick one. And it was built with accessibility in mind: you can click and drag to scroll for anyone who finds a mouse wheel hard, scrollbars are wide and always visible, long pages have jump-to-top and bottom buttons, and text scales up without breaking the layout.

## 11. Less exposure, more understanding, no one-way doors
*~50 seconds*

So why use it? Three reasons. One: it shrinks what an attacker can reach if a service is ever compromised, and the measure of progress is systemd's own exposure score, so the improvement is real and anyone can check it. Two: it teaches as it goes. Most admins know hardening matters but don't have time to study forty directives; SysdSafe turns each one into a plain question with advice and the real man-page text, so your team gets better at this, not just your servers. Three: it makes change safe. It takes a backup first, keeps its change in one separate file, and gives you a one-click way back. And because it's open source under the AGPL, the small helper that runs as root is a few dozen lines that anyone can read before they trust it.

## 12. How a release is checked
*~55 seconds*

[Fill in the bracketed results from the 1.0.12 release run before presenting.] Here's how a release is checked. There are twenty-five automated tests covering what matters most for safety: rejecting unsafe service names, the protected-service list, a test that fails if the app and the root helper ever disagree on what's protected or allowed, byte-exact drop-in content, parsing systemd's output, and the restore path. [__ of 25 passed for 1.0.12.] The root helper itself was run against sixteen hostile inputs, like mismatched paths, injected ExecStartPre lines, option-style names and path traversal, and refused every one. Manual reviews of the privileged path fixed two defects in 1.0.5 and, in 1.0.12, the lockout risks, where files were stored, and links opening as root. Snyk code and dependency scans [found __ issues] for this release, the SBOM lists [__] components, and every package is signed with a detached GPG signature, with the public key and a SHA-512 checksum alongside it.

## 13. Where SysdSafe goes next
*~45 seconds*

Where does it go from here? 1.0.12 already closed the biggest gaps from my own review: a much wider protected-service list enforced by both the app and the root helper, a helper that can only ever write the five Tier one lines, a second health check, and links that never open as root. Two things are next. First, checking dependent services: after a change, look at the units that rely on the one you hardened, not just the one itself. Second, an independent review of the root launcher, the helper and the polkit policy, because the part of a security tool that runs as root deserves outside eyes. Happy to take questions, or to do a quick live demo: scan a machine, harden one service, and restore it with one click.
