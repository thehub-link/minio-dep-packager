# MinIO Debian Package Builder

This project provides a **custom script** to build MinIO as a **Debian `.deb` package**, with systemd integration and proper post-install/post-remove handling. It also includes a **GitHub Actions workflow** to build the package automatically and upload it as an artifact.

---

## Features

- Builds MinIO from any tag or commit.  
- Creates a proper Debian package with:
  - `/usr/local/bin/minio` binary
  - `/etc/default/minio` configuration (preserved if exists)
  - `systemd` service file (preserved if exists)  
- Handles installation/removal cleanly:
  - Creates `minio-user` if missing
  - Stops/disables service on remove
  - Purges configuration on `apt purge`
- Can be triggered manually in **GitHub Actions**.

---

## Requirements

- **Linux environment** (tested on Ubuntu).  
- **Go** (>= 1.23).  
- **dpkg-dev**, **git**, **build-essential**.

---

## Usage

### Local build

```bash
# Optional: override defaults
export REPO_URL="https://github.com/minio/minio.git"
export BUILD_DIR="$HOME/minio-build"

# Run the build script
./src/build-minio.sh RELEASE.2025-08-13T08-35-41Z

# Resulting .deb package:
ls dist/
```

- The build script will create a `.deb` package in the `dist/` directory.  
- The systemd service and `/etc/default/minio` will **not overwrite existing files**.  

---

### GitHub Actions

Trigger a manual build via **workflow_dispatch**:

1. Go to **Actions → Build MinIO Debian Package**.  
2. Click **Run workflow** and select a branch.  
3. Specify a **MinIO release tag** (e.g., `RELEASE.2025-08-13T08-35-41Z`).  
4. After the workflow completes, download the `.deb` from **Artifacts**.

**Workflow uses:**

- `src/build-minio.sh` script  
- Ubuntu runners with Go 1.23  
- HTTPS clone of the MinIO repository  

---

## Debian Package Details

- **Binary:** `/usr/local/bin/minio`  
- **User:** `minio-user` (system user created automatically if missing)  
- **Systemd Service:** `/usr/lib/systemd/system/minio.service`  
- **Config:** `/etc/default/minio`  
- **Package Name:** `minio`  
- **Architecture:** `amd64`  

### Post-installation

- The `postinst` script ensures the user and systemd service exist.  
- Existing configuration or service files are **preserved**.

### Post-removal

- `remove`: stops and disables service  
- `purge`: removes systemd service, configuration, and user

---

## Customization

You can override defaults via **environment variables**:

| Variable   | Default                                | Description                  |
|-----------|----------------------------------------|------------------------------|
| `REPO_URL` | `https://github.com/minio/minio.git`  | Git repository to clone      |
| `TAG`      | `RELEASE.2025-08-13T08-35-41Z`       | MinIO tag to build           |
| `BUILD_DIR`| `./build`                             | Directory used for building  |

---

## GitHub Actions Workflow

The project includes a workflow to build the `.deb` automatically:

```yaml
name: Build MinIO Debian Package

on:
  workflow_dispatch:
    inputs:
      tag:
        description: "MinIO release tag (e.g. RELEASE.2025-08-13T08-35-41Z)"
        required: true
        default: "RELEASE.2025-08-13T08-35-41Z"

jobs:
  build:
    name: Build MinIO .deb
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: "1.23"

      - name: Cache Go modules
        uses: actions/cache@v4
        with:
          path: |
            ~/go/pkg/mod
            ~/.cache/go-build
          key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
          restore-keys: |
            ${{ runner.os }}-go-

      - name: Install build dependencies
        run: sudo apt-get update && sudo apt-get install -y git build-essential dpkg-dev

      - name: Run build script
        run: |
          chmod +x src/build-minio.sh
          ./src/build-minio.sh "${{ github.event.inputs.tag }}"
        env:
          REPO_URL: https://github.com/minio/minio.git

      - name: Upload package artifact
        uses: actions/upload-artifact@v4
        with:
          name: minio-deb-package
          path: dist/*.deb
```

---

## License

This project is **open source**. MinIO is distributed under [Apache License 2.0](https://github.com/minio/minio/blob/master/LICENSE).

