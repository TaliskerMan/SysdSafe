#!/bin/bash
set -e

# Versioning logic
VERSION_FILE="scripts/.version"
if [ -f "$VERSION_FILE" ]; then
  VERSION=$(cat "$VERSION_FILE")
  IFS='.' read -r -a parts <<< "$VERSION"
  parts[2]=$((parts[2] + 1))
  VERSION="${parts[0]}.${parts[1]}.${parts[2]}"
else
  VERSION="1.0.0"
fi

# Ensure the scripts directory exists in case we are running from root
mkdir -p scripts
echo "$VERSION" > "$VERSION_FILE"

echo "Building SysdSafe version $VERSION..."

# Build Flutter App
flutter build linux --release

APP_NAME="sysdsafe"
BUILD_DIR="build/linux/x64/release/bundle"
DEB_DIR="${APP_NAME}_${VERSION}_amd64"

echo "Preparing DEB package directory: $DEB_DIR"
rm -rf "$DEB_DIR"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/usr/bin"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/pixmaps"
mkdir -p "$DEB_DIR/opt/$APP_NAME"

# Copy binary and assets
cp -r "$BUILD_DIR"/* "$DEB_DIR/opt/$APP_NAME/"

# Create executable wrapper
cat <<EOF > "$DEB_DIR/usr/bin/$APP_NAME"
#!/bin/bash
cd /opt/$APP_NAME
exec ./$APP_NAME "\$@"
EOF
chmod +x "$DEB_DIR/usr/bin/$APP_NAME"

# Copy Icon
cp assets/sysdsafe.png "$DEB_DIR/usr/share/pixmaps/$APP_NAME.png"

# Create Desktop Entry
cat <<EOF > "$DEB_DIR/usr/share/applications/$APP_NAME.desktop"
[Desktop Entry]
Name=SysdSafe
Comment=Systemd Service Security Hardening
Exec=$APP_NAME
Icon=$APP_NAME
Terminal=false
Type=Application
Categories=Utility;System;Security;
EOF

# Create DEBIAN/control
cat <<EOF > "$DEB_DIR/DEBIAN/control"
Package: $APP_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Maintainer: SysdSafe Developers <maintainer@example.com>
Description: SysdSafe - Systemd Service Security Hardening Tool
 A Flutter application designed to audit and harden systemd services 
 using automated Polkit drop-in configurations.
EOF

# Set permissions
chmod -R 755 "$DEB_DIR"

# Build DEB
echo "Building package..."
dpkg-deb --build "$DEB_DIR"

echo "Package created: ${DEB_DIR}.deb"

# Clean up build directory structure to leave only the DEB file
rm -rf "$DEB_DIR"

echo "Ready for release to GitHub!"
