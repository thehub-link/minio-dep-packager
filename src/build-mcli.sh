#!/usr/bin/env bash
set -euo pipefail

# ==============================
# Configuration
# ==============================
REPO_URL="${REPO_URL:-https://github.com/minio/mc.git}"   # Git repository (SSH)
TAG="${1:-${TAG:-RELEASE.2025-08-13T08-35-41Z}}"       # tag à builder
BUILD_DIR="${BUILD_DIR:-$(pwd)/build}"                 # dossier de build
PKG_NAME="mcli"
ARCH="amd64"
PKG_VERSION="${TAG/RELEASE./}"                         # version Debian
INSTALL_PATH="/usr/local/bin"

# ==============================
# Préparation
# ==============================
rm -rf "$BUILD_DIR/$PKG_NAME-$TAG"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "📥 Clonage du dépôt $REPO_URL à partir du tag $TAG..."
git clone --branch "$TAG" --depth 1 "$REPO_URL" "$PKG_NAME"
cd "$PKG_NAME"

# ==============================
# Détermination du module et commit
# ==============================
MODULE_PATH=$(grep -m1 "^module " go.mod | awk '{print $2}')
if [ -z "$MODULE_PATH" ]; then
  echo "❌ Impossible de détecter le module Go."
  exit 1
fi

COMMIT_ID=$(git rev-parse HEAD)
SHORT_COMMIT_ID=$(echo "$COMMIT_ID" | cut -c1-12)

echo "📄 Module Go: ${MODULE_PATH}"
echo "🔢 Commit complet: ${COMMIT_ID}"
echo "🔹 Commit court:   ${SHORT_COMMIT_ID}"

# ==============================
# Compilation
# ==============================
echo "🏗️  Compilation du binaire..."
BUILD_ROOT="$BUILD_DIR/${PKG_NAME}-${TAG}"
mkdir -p "$BUILD_ROOT"

go build -o "$BUILD_ROOT/mcli" -ldflags "-s -w \
  -X ${MODULE_PATH}/cmd.Version=$TAG \
  -X ${MODULE_PATH}/cmd.ReleaseTag=$TAG \
  -X ${MODULE_PATH}/cmd.CommitID=$COMMIT_ID \
  -X ${MODULE_PATH}/cmd.ShortCommitID=$SHORT_COMMIT_ID"

# ==============================
# Structure du package Debian
# ==============================
cd "$BUILD_ROOT"
mkdir -p DEBIAN "usr/local/bin" "lib/systemd/system"

# Fichier de contrôle
cat > DEBIAN/control <<EOF
Package: mcli
Version: ${PKG_VERSION}
Section: net
Priority: optional
Architecture: ${ARCH}
Maintainer: MinIO Packaging <support@min.io>
Description: MinIO Client (mcli) — outil de gestion pour MinIO et S3
EOF

# Copier le binaire dans l’arborescence du package
install -m 755 mcli "usr/local/bin/mcli"

# ==============================
# Création du .deb
# ==============================
echo "📦 Création du package Debian..."
cd "$BUILD_DIR"
dpkg-deb --build --root-owner-group "${PKG_NAME}-${TAG}"

echo "✅ Package créé : $BUILD_DIR/${PKG_NAME}-${TAG}.deb"

# ==============================
# Création du répertoire dist
# ==============================
DIST_DIR="$(dirname "$BUILD_DIR")/dist"
mkdir -p "$DIST_DIR"

# Déplacer le package dans dist/
echo "📦 Déplacement du paquet final dans $DIST_DIR..."
mv "$BUILD_DIR/${PKG_NAME}-${TAG}.deb" "$DIST_DIR/"

echo "✅ Package créé : $DIST_DIR/${PKG_NAME}-${TAG}.deb"
