# SysdSafe - Comprehensive User Guide

Welcome to **SysdSafe**! This utility is an advanced hardening and audit tool designed specifically to help you analyze and secure your Linux systemd services. 

Our fundamental guiding principle is **"First, do no harm."** Systemd is the core init system for most modern Linux distributions, managing everything from basic network connectivity to critical web servers. SysdSafe is engineered to help you carefully review, understand, and alter your systemd services to minimize the attack surface of your hosts without breaking them.

---

## ⚠️ 1. Critical Philosophy: Safety First

SysdSafe is a powerful tool. Applying security restrictions improperly can cause critical services to fail, applications to crash, or your machine to become unbootable. 

To prevent catastrophic harm, SysdSafe **does not** apply blanket settings across all services. Every host is unique, and security must be tailored to your specific environment.

**When using SysdSafe, you must adhere to these rules:**
1. **Examine Your Host's Use Case:** Before modifying a service, understand exactly what that service does on your specific host. Does it need network access? Does it need to write to `/var/log`? 
2. **Make Slow, Careful Changes:** Do not attempt to lock down every service in a single session. Secure one service, reboot or restart the service, test its functionality, and then move on to the next.
3. **Avoid Altering What You Do Not Understand:** If you do not know what `ProtectSystem=strict` or `PrivateNetwork=yes` actually does to a specific daemon, *do not apply the fix* until you have researched it.

---

## 💾 2. Installation Instructions

SysdSafe is distributed natively as a Debian package (`.deb`). 

To install it on Debian, Ubuntu, or derivative distributions, execute the following commands in your terminal:

```bash
# Install the package
sudo dpkg -i sysdsafe_1.0.2_amd64.deb

# If you encounter any missing dependency errors, resolve them with:
sudo apt-get install -f
```

---

## 🎮 3. Navigation & Setup

Upon launching SysdSafe (via your desktop application menu or by running `sysdsafe` in your terminal), the application will immediately begin scanning your `systemd` service files. No initial configuration is required.

**The Interface:**
* **Dashboard / Service List:** Displays all detected services, rated by urgency (High, Medium, Low). Ratings are based on known risk factors, such as services running as root or lacking process isolation.
* **Service Detail View:** Tapping a service opens a detailed view where SysdSafe parses the service's configuration and corresponding manual pages to provide context on what the service actually does.
* **Logs Tab:** A dedicated tab for viewing historical actions and errors.

---

## 🛠️ 4. Usage: Auditing & Hardening (Auto-Fix)

### Auditing a Service
1. Select a service from the main list.
2. Read the provided documentation context carefully to understand its role.
3. Review the specific security vulnerabilities identified (e.g., missing memory protection directives).

### Applying an Auto-Fix (Carefully!)
If you understand the service and agree with the suggested security directives:
1. Tap the **Apply Auto-Fix** button.
2. SysdSafe will create a systemd configuration drop-in file (in `/etc/systemd/system/`).
3. **Authorization:** You will be prompted for your password. SysdSafe securely executes these surgical changes via `pkexec`, ensuring the entire application does not run as root.

### Recovery & Reverting Changes
Because we prioritize the "first, do no harm" approach, SysdSafe includes an atomic backup and revert mechanism:
* **Automatic Backups:** Before any Auto-Fix is applied, the original service state is safely backed up to `~/sysdsafe_backups/`. 
* **Reverting:** If you make a slow, careful change and suddenly find that the service is failing, simply navigate back to that service's detail page and tap **Revert Auto-Fix**. SysdSafe will instantly remove the custom drop-in file and restore the service to its original working configuration.

---

## 📝 5. Logging & Support

SysdSafe utilizes a robust, persistent logging facility to track application events, including when you apply or revert an Auto-Fix.

* **Log Location:** Logs are securely stored at `~/.local/state/sysdsafe/app.log`.
* **In-App Viewing:** You can view these logs directly in the **Logs** tab via the bottom navigation bar.

**Obtaining Support:**
If you encounter a systemic issue or bug that you cannot recover from:
1. Open the **Logs** tab and click the **Email Support** button.
2. Your default email client will open, pre-filled with our support address.
3. **Please manually attach your `app.log` file** so our team can carefully review the issue and help you safely resolve it.

---
*Stay safe. Build securely. Do no harm.*
