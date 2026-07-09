#!/bin/bash
set -e

# Versioning: single source of truth from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
if [ -z "$VERSION" ]; then
  echo "ERROR: could not read version from pubspec.yaml" >&2
  exit 1
fi

echo "Building SysdSafe version $VERSION for Linux..."

# Fix clang++ linker issue on some arm64/Linux environments
if [ -d "/usr/lib/gcc/aarch64-linux-gnu/13" ]; then
    export LIBRARY_PATH="/usr/lib/gcc/aarch64-linux-gnu/13:${LIBRARY_PATH:-}"
fi
if [ -d "/usr/include/c++/13" ]; then
    export CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/aarch64-linux-gnu/c++/13:${CPLUS_INCLUDE_PATH:-}"
fi

ARCH=$(dpkg --print-architecture)

# Clean and Build Flutter App
flutter clean
flutter build linux --release

echo "Generating SBOM into Audit folder..."
mkdir -p Audit
flutter pub deps > Audit/sbom.txt

echo "Running packaging script..."
./scripts/package_deb.sh

DEB_FILE="sysdsafe_${VERSION}_${ARCH}.deb"

echo "Generating Checksums..."
sha512sum "$DEB_FILE" > "${DEB_FILE}.sha512"

echo "Signing package with GPG..."
if command -v gpg > /dev/null 2>&1; then
    gpg --local-user chuck@nordheim.online --detach-sign --armor "$DEB_FILE"
    gpg --export -a chuck@nordheim.online > "pubkey.asc"
else
    echo "WARNING: GPG not found - package NOT signed!"
fi

# Copy to NOBuilds directory
echo "Copying to NOBuilds directory..."
NOBUILDS_DIR="${HOME}/NOBuilds/SysdSafe/v${VERSION}"
mkdir -p "${NOBUILDS_DIR}"

cp "${DEB_FILE}" "${NOBUILDS_DIR}/"
cp "${DEB_FILE}.asc" "${NOBUILDS_DIR}/" || true
cp "${DEB_FILE}.sha512" "${NOBUILDS_DIR}/" || true
cp pubkey.asc "${NOBUILDS_DIR}/" || true
cp LICENSE "${NOBUILDS_DIR}/"
cp README.md "${NOBUILDS_DIR}/"
cp Audit/sbom.txt "${NOBUILDS_DIR}/" || true

# Generate source code archive
echo "Generating source tarball..."
tar --exclude=build --exclude=.dart_tool --exclude=.git -czf "${NOBUILDS_DIR}/sysdsafe_source.tar.gz" .

echo "Build and Release packaging complete for SysdSafe!"
