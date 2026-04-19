#!/bin/bash
set -e

echo "Building SysdSafe for Linux..."
flutter build linux

echo "Generating SBOM into Audit folder..."
mkdir -p Audit
flutter pub deps > Audit/sbom.txt

echo "Running security checks as per ShadowAgent rules..."
# Basic check to ensure no plain text passwords or insecure practices in dart files
if grep -r -i "password=" lib/; then
  echo "WARNING: Potential hardcoded password found."
fi

echo "Build and Audit complete. Output is in build/linux/x64/release/bundle"
