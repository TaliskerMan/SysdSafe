#!/bin/bash
set -e

echo "=== SysdSafe Release Publisher ==="

# Define the GPG Key
GPG_KEY="1779CD0F50DBB64C187908264863C73517D810F8"

# Ensure we are in the correct directory (sysdsafe root)
if [ ! -d "scripts" ]; then
    echo "Error: Please run this script from the root of the sysdsafe repository."
    echo "Usage: ./scripts/publish_release.sh"
    exit 1
fi

# Extract the version from the .version file
if [ ! -f "scripts/.version" ]; then
    echo "Error: scripts/.version not found."
    exit 1
fi

VERSION=$(cat scripts/.version)
DEB_FILE="sysdsafe_${VERSION}_amd64.deb"

if [ ! -f "$DEB_FILE" ]; then
    echo "Error: $DEB_FILE not found. Please run ./scripts/package_deb.sh first."
    exit 1
fi

echo "1. Generating SHA512 Checksums..."
sha512sum "$DEB_FILE" > "${DEB_FILE}.sha512"

echo "2. Exporting Public GPG Key ($GPG_KEY)..."
gpg --armor --export "$GPG_KEY" > pubkey.asc

echo "3. Signing the DEB package..."
# Remove any existing signature to avoid conflict
rm -f "${DEB_FILE}.sig"
gpg -u "$GPG_KEY" --detach-sign --armor --output "${DEB_FILE}.sig" "$DEB_FILE"

echo "4. Creating GitHub Release and Uploading Assets..."
# Verify gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed or not in PATH."
    echo "Please install it from https://cli.github.com/ and authenticate with 'gh auth login'"
    exit 1
fi

# Check if it's a git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: This directory is not a git repository."
    echo "Please initialize git, add your remote, commit, and push your changes before releasing."
    exit 1
fi

# Make sure we don't try to create a release tag that already exists, unless intended
# Or let gh handle the error if it exists.

gh release create "v$VERSION" \
    --title "SysdSafe v$VERSION" \
    --notes "Official Release of SysdSafe version $VERSION. See \`docs/USER_GUIDE.md\` for installation instructions and security disclosures." \
    "$DEB_FILE" \
    "${DEB_FILE}.sig" \
    "${DEB_FILE}.sha512" \
    pubkey.asc \
    docs/USER_GUIDE.md

echo "====================================================="
echo "Success! Release v$VERSION published successfully to GitHub."
echo "====================================================="
