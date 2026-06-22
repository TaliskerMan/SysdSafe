# SysdSafe Snyk Security Audit Report

**Date:** April 21, 2026
**Target:** `sysdsafe` Repository

## Executive Summary

A security audit of the SysdSafe application was conducted using the Snyk developer security platform. The audit included Static Application Security Testing (SAST) for the first-party codebase and Software Composition Analysis (SCA) for third-party dependencies.

The scan confirmed that the first-party Dart/Flutter source code is completely clean. One low-severity issue was found in a third-party dependency.

## Scope & Limitations

This report covers **dependency CVEs (SCA)** and **generic code-pattern issues (SAST)**. It is *not* a verdict on the correctness of SysdSafe's privileged hardening logic. In particular, Snyk did not (and could not) catch two correctness issues found during manual review and fixed in 1.0.5:

- the `printf "%b"` drop-in write, which could corrupt directives containing `%` specifiers or backslashes (P0-#1); and
- the audit file being written relative to the current working directory (P1-#2).

Treat the clean SAST/SCA result as "no known-vulnerable dependencies or obvious unsafe patterns," not as an assurance that the privileged file-writing and service-restart behavior is correct — that is covered by manual review and the unit tests under `test/`.

## Scan Details

### 1. Snyk Code Scan (SAST)
- **Tool:** `mcp_Snyk_snyk_code_scan`
- **Scope:** Full repository including first-party Dart source files.
- **Findings:** **0 Issues.**
  - The first-party source code in the SysdSafe repository has no identified security vulnerabilities.

### 2. Snyk Open Source Scan (SCA)
- **Tool:** `mcp_Snyk_snyk_sca_scan`
- **Scope:** Third-party package dependencies defined in `pubspec.yaml` and their transitive dependencies.
- **Findings:** **1 Low-Severity Issue.**

  * **Issue 1: Information Exposure (CVE-2020-29582)**
    * **Package:** `org.jetbrains.kotlin:kotlin-stdlib`
    * **Severity:** Low
    * **Current Version:** `1.9.22`
    * **Fixed Version:** `2.1.0`
    * **Details:** This issue originates from the Java/Kotlin build files within a third-party dependency (`jni-1.0.0`) cached in `.pub-cache/hosted/pub.dev/jni-1.0.0/java/build.gradle.kts`. It is a known low-severity issue in the Kotlin standard library prior to version 2.1.0.

## Conclusion & Recommendations

The SysdSafe application source code is highly secure (0 SAST issues). 

The single dependency finding is a Low-severity issue deep within the Android/Kotlin build graph of the `jni` plugin. Because it only affects the build environment (via a `build.gradle.kts` file) and is classified as low severity, it poses minimal risk to the compiled Linux desktop application. 

**Recommended Action:**
- Monitor for updates to the `jni` Dart package (if utilized) that bump its internal Kotlin dependency to `>=2.1.0`. Since the risk is low and isolated to the Kotlin build toolchain, no immediate code change or emergency patch is strictly required unless targeting Android where Kotlin is actively compiled into the runtime bundle.
