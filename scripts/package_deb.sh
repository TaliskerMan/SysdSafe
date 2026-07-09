#!/bin/bash
set -e

# Versioning: pubspec.yaml is the single source of truth (no auto-increment).
# This prevents the drift between pubspec, scripts/.version, the git tag, and
# the built .deb. scripts/.version is kept in sync for any external consumers.
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
if [ -z "$VERSION" ]; then
  echo "ERROR: could not read version from pubspec.yaml" >&2
  exit 1
fi
mkdir -p scripts
echo "$VERSION" > scripts/.version

echo "Building SysdSafe version $VERSION..."

# Fix clang++ linker issue on some arm64/Linux environments
if [ -d "/usr/lib/gcc/aarch64-linux-gnu/13" ]; then
    export LIBRARY_PATH="/usr/lib/gcc/aarch64-linux-gnu/13:${LIBRARY_PATH:-}"
fi
if [ -d "/usr/include/c++/13" ]; then
    export CPLUS_INCLUDE_PATH="/usr/include/c++/13:/usr/include/aarch64-linux-gnu/c++/13:${CPLUS_INCLUDE_PATH:-}"
fi

ARCH=$(dpkg --print-architecture)
UNAME_M=$(uname -m)
if [ "$UNAME_M" = "x86_64" ]; then
    FLUTTER_ARCH="x64"
elif [ "$UNAME_M" = "aarch64" ]; then
    FLUTTER_ARCH="arm64"
else
    FLUTTER_ARCH="$UNAME_M"
fi

APP_NAME="sysdsafe"
BUILD_DIR="build/linux/${FLUTTER_ARCH}/release/bundle"
DEB_DIR="${APP_NAME}_${VERSION}_${ARCH}"

echo "Preparing DEB package directory: $DEB_DIR"
rm -rf "$DEB_DIR"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/usr/bin"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$DEB_DIR/usr/lib/$APP_NAME"
mkdir -p "$DEB_DIR/usr/share/polkit-1/actions"
mkdir -p "$DEB_DIR/opt/$APP_NAME"

# Copy binary and assets
cp -r "$BUILD_DIR"/* "$DEB_DIR/opt/$APP_NAME/"

# Install the privileged helper and its polkit policy (P1-#5).
install -m 0755 linux/packaging/sysdsafe-helper "$DEB_DIR/usr/lib/$APP_NAME/sysdsafe-helper"
install -m 0644 linux/packaging/online.nordheim.sysdsafe.policy "$DEB_DIR/usr/share/polkit-1/actions/online.nordheim.sysdsafe.policy"

# Create executable wrapper
cat <<EOF > "$DEB_DIR/usr/bin/$APP_NAME"
#!/bin/bash
cd /opt/$APP_NAME
exec ./$APP_NAME "\$@"
EOF
chmod +x "$DEB_DIR/usr/bin/$APP_NAME"

# Copy Icon
cp assets/sysdsafe.png "$DEB_DIR/usr/share/icons/hicolor/256x256/apps/com.example.sysdsafe.png"

# Create Desktop Entry
cat <<EOF > "$DEB_DIR/usr/share/applications/com.example.sysdsafe.desktop"
[Desktop Entry]
Name=SysdSafe
Comment=Systemd Service Security Hardening
Exec=$APP_NAME
Icon=com.example.sysdsafe
Terminal=false
Type=Application
Categories=Utility;System;Security;
StartupWMClass=com.example.sysdsafe
EOF

# Create DEBIAN/control
cat <<EOF > "$DEB_DIR/DEBIAN/control"
Package: $APP_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: polkit | policykit-1, systemd
Maintainer: Chuck Talk <chuck@nordheim.online>
Description: SysdSafe - Systemd Service Security Hardening Tool
 A Flutter application designed to audit and harden systemd services 
 using automated Polkit drop-in configurations.
EOF

# Set permissions
chmod -R 755 "$DEB_DIR"

# Build DEB. --root-owner-group forces root:root ownership inside the package,
# which pkexec REQUIRES for /usr/lib/sysdsafe/sysdsafe-helper (a helper owned by
# a non-root user would be rejected as an authorization-bypass risk).
echo "Building package..."
dpkg-deb --root-owner-group --build "$DEB_DIR"

DEB_FILE="${APP_NAME}_${VERSION}_${ARCH}.deb"
echo "Package created: ${DEB_FILE}"

# Clean up build directory structure to leave only the DEB file
rm -rf "$DEB_DIR"

echo "Ready for release to GitHub!"
