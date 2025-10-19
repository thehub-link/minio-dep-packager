#!/usr/bin/env bash
set -euo pipefail

# ==============================
# Configuration
# ==============================
REPO_URL="${REPO_URL:-git@github.com:minio/minio.git}"   # Git repository (SSH)
TAG="${1:-${TAG:-RELEASE.2025-08-13T08-35-41Z}}"         # Tag to build
BUILD_DIR="${BUILD_DIR:-$(pwd)/build}"                   # Build directory
PKG_NAME="minio"
ARCH="amd64"
PKG_VERSION="$(echo "${TAG/RELEASE./}" | tr 'T:-Z' '.')" # Debian-compatible version
INSTALL_PATH="/usr/local/bin"

# ==============================
# Preparation
# ==============================
rm -rf "$BUILD_DIR/$PKG_NAME-$TAG"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "📥 Cloning repository $REPO_URL (tag $TAG)..."
git clone --depth 1 "$REPO_URL" "$PKG_NAME"
cd "$PKG_NAME"

echo "🔖 Checking out tag $TAG..."
git fetch --tags
git checkout "tags/$TAG"

# ==============================
# Module and commit info
# ==============================
MODULE_PATH=$(grep -m1 "^module " go.mod | awk '{print $2}')
if [ -z "$MODULE_PATH" ]; then
  echo "❌ Unable to detect Go module path."
  exit 1
fi

COMMIT_ID=$(git rev-parse HEAD)
SHORT_COMMIT_ID=$(echo "$COMMIT_ID" | cut -c1-12)

echo "📄 Go module: ${MODULE_PATH}"
echo "🔢 Full commit: ${COMMIT_ID}"
echo "🔹 Short commit: ${SHORT_COMMIT_ID}"

# ==============================
# Build
# ==============================
echo "🏗️  Building MinIO binary..."
BUILD_ROOT="$BUILD_DIR/${PKG_NAME}-${TAG}"
mkdir -p "$BUILD_ROOT"

go build -o "$BUILD_ROOT/minio" -ldflags "-s -w \
  -X ${MODULE_PATH}/cmd.Version=$TAG \
  -X ${MODULE_PATH}/cmd.ReleaseTag=$TAG \
  -X ${MODULE_PATH}/cmd.CommitID=$COMMIT_ID \
  -X ${MODULE_PATH}/cmd.ShortCommitID=$SHORT_COMMIT_ID"

# ==============================
# Debian package structure
# ==============================
cd "$BUILD_ROOT"
mkdir -p DEBIAN "usr/local/bin"

# Control file
cat > DEBIAN/control <<EOF
Package: minio
Version: ${PKG_VERSION}
Section: net
Priority: optional
Architecture: ${ARCH}
Maintainer: MinIO Packaging <support@min.io>
Depends: adduser
Description: MinIO Server — S3-compatible object storage server
EOF

# Copy the binary
install -m 755 minio "usr/local/bin/minio"

# ------------------------------
# Post-install script
# ------------------------------
cat > DEBIAN/postinst <<'EOF'
#!/bin/sh
set -e

# Create minio-user if missing
if ! id -u minio-user >/dev/null 2>&1; then
  adduser --system --group --no-create-home --disabled-login minio-user
fi

# Install default config if not present
if [ ! -f /etc/default/minio ]; then
  mkdir -p /etc/default
  cat > /etc/default/minio <<'EOC'
# Example:
# MINIO_VOLUMES="/data"
# MINIO_OPTS="--console-address :9001"
EOC
  echo "Installed default /etc/default/minio"
else
  echo "Keeping existing /etc/default/minio"
fi

# Install systemd service if not present
if [ ! -f /usr/lib/systemd/system/minio.service ]; then
  mkdir -p /usr/lib/systemd/system
  cat > /usr/lib/systemd/system/minio.service <<'EOC'
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
Type=notify
WorkingDirectory=/usr/local
User=minio-user
Group=minio-user
ProtectProc=invisible
EnvironmentFile=-/etc/default/minio
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES
Restart=always
LimitNOFILE=1048576
MemoryAccounting=no
TasksMax=infinity
TimeoutSec=infinity
OOMScoreAdjust=-1000
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
EOC
  echo "Installed default /usr/lib/systemd/system/minio.service"
else
  echo "Keeping existing /usr/lib/systemd/system/minio.service"
fi

systemctl daemon-reload || true
EOF
chmod 755 DEBIAN/postinst

# ------------------------------
# Post-remove script
# ------------------------------
cat > DEBIAN/postrm <<'EOF'
#!/bin/sh
set -e

case "$1" in
  remove)
    echo "Stopping and disabling MinIO service..."
    systemctl stop minio.service 2>/dev/null || true
    systemctl disable minio.service 2>/dev/null || true
    ;;
  purge)
    echo "Purging MinIO configuration and user..."
    rm -f /usr/lib/systemd/system/minio.service
    rm -f /etc/default/minio
    deluser --system --quiet minio-user 2>/dev/null || true
    ;;
esac

exit 0
EOF
chmod 755 DEBIAN/postrm

# ==============================
# Build the .deb
# ==============================
echo "📦 Building Debian package..."
cd "$BUILD_DIR"
dpkg-deb --build --root-owner-group "${PKG_NAME}-${TAG}"

echo "✅ Package created: $BUILD_DIR/${PKG_NAME}-${TAG}.deb"

# ==============================
# Move to dist/
# ==============================
DIST_DIR="$(dirname "$BUILD_DIR")/dist"
mkdir -p "$DIST_DIR"

echo "📦 Moving final package to $DIST_DIR..."
mv "$BUILD_DIR/${PKG_NAME}-${TAG}.deb" "$DIST_DIR/"

echo "✅ Done: $DIST_DIR/${PKG_NAME}-${TAG}.deb"
