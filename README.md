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

---

## License

The script included in this repository is licensed under the [MIT License](LICENSE-MIT).  

## Disclaimer

The MinIO binaries produced by this script are from the original [MinIO project](https://github.com/minio/minio) and are licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).  
All copyright and license information of MinIO are retained from the original project. This repository does not modify MinIO's source code.
