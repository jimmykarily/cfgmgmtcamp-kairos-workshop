# Local Infrastructure Setup (MacOS)

This folder contains the local services needed to run the Kairos workshop entirely on MacOS without external dependencies like GitHub or public container registries.

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| **Gitea** | http://localhost:3000 | Local Git server (replaces GitHub) |
| **Gitea DB** | (internal) | MySQL 8 database for Gitea |
| **Registry** | http://localhost:5000 | Local container registry |
| **Registry UI** | http://localhost:8080 | Browse registry contents |

Data persistence:
- Gitea and MySQL use Docker named volumes (`gitea-data`, `gitea-config`, `mysql-data`)
- Registry uses local bind mount (`./data/registry/`)

## Prerequisites

- Docker Desktop or Podman Desktop installed
- `docker compose` or `podman-compose` available

### Podman Users

If using Podman, ensure you have `podman-compose` installed:

```bash
brew install podman-compose
```

## Quick Start

### 1. Start the services

```bash
cd macos/local-infra

# With Docker
docker compose up -d

# With Podman
podman-compose up -d
```

### 2. Verify services are running

```bash
# Check containers
podman-compose ps

# Test registry
curl http://localhost:5000/v2/_catalog

# Open Gitea (first time will show setup wizard)
open http://localhost:3000
```

### 3. Configure Gitea (first run only)

1. Open http://localhost:3000
2. Complete the initial setup wizard:
   - Database: MySQL is pre-configured via environment variables
   - Site Title: `Kairos Workshop`
   - Leave other settings as default
3. Click **Install Gitea**
4. Register your first user (this becomes the admin)

### 4. Configure Podman for insecure registry

Since the registry runs over HTTP, use `--tls-verify=false` when pushing/pulling:

```bash
podman push --tls-verify=false localhost:5000/kairos-custom:latest
```

## Usage in Workshop

### Pushing images to local registry

```bash
# Tag your image for local registry
podman tag localhost/kairos-custom:latest localhost:5000/kairos-custom:latest

# Push to local registry
podman push --tls-verify=false localhost:5000/kairos-custom:latest

# Verify
curl http://localhost:5000/v2/_catalog
# Output: {"repositories":["kairos-custom"]}
```

### Building ISOs with AuroraBoot

> [!WARNING]
> **Known limitation — HTTP registry + AuroraBoot + Podman on MacOS**:
> - The local registry runs over HTTP. Podman on MacOS requires `--tls-verify=false` for HTTP registries because the insecure registry config lives inside the Podman machine VM, not on the host.
> - AuroraBoot uses Go container libraries that default to HTTPS with no insecure registry flag. Adding self-signed certs to the registry solves Podman but not AuroraBoot — it would need patching to trust custom CAs.
> - **Workaround**: Push to [ttl.sh](https://ttl.sh) (free, anonymous, temporary public registry) for ISO builds.

A named volume avoids permission issues on MacOS:

```bash
# Push to ttl.sh (image expires after 1 hour)
podman tag localhost/kairos-custom:latest ttl.sh/kairos-custom:1h
podman push ttl.sh/kairos-custom:1h

# Create a build volume
podman volume create kairos-build

# Build the ISO
podman run --privileged -it --rm \
  -v kairos-build:/result \
  quay.io/kairos/auroraboot:latest \
  build-iso --output /result ttl.sh/kairos-custom:1h

# Extract the ISO
mkdir -p ~/kairos-workshop/build
podman run --rm \
  -v kairos-build:/source:ro \
  -v ~/kairos-workshop/build:/dest \
  alpine sh -c "cp /source/*.iso /dest/ && ls -lh /dest/"
```

### Creating a repo in Gitea

1. Open http://localhost:3000
2. Click **+** → **New Repository**
3. Name it `kairos-custom`
4. Click **Create Repository**
5. Clone locally:

```bash
git clone http://localhost:3000/<username>/kairos-custom.git
# or via SSH:
git clone ssh://git@localhost:2222/<username>/kairos-custom.git
```

## Data Storage

Data is persisted using:

| Service | Storage | Location |
|---------|---------|----------|
| Gitea | Docker volume | `gitea-data`, `gitea-config` |
| MySQL | Docker volume | `mysql-data` |
| Registry | Bind mount | `./data/registry/` |

The `./data/` folder is git-ignored.

## Stopping the services

```bash
# Stop but keep data
docker compose down

# Clean slate: remove volumes and local data
docker compose down -v
rm -rf ./data
```

## Troubleshooting

### Port conflicts

If ports 3000, 5000, or 8080 are already in use, edit `docker-compose.yml` and change the host port (left side of the colon):

```yaml
ports:
  - "3001:3000"  # Changed from 3000 to 3001
```

### Registry push fails with "http: server gave HTTP response to HTTPS client"

Use `--tls-verify=false` on push/pull commands (see step 4 above).

### Gitea can't connect to database

Make sure the `kairos-gitea-db` container is running and healthy:

```bash
docker compose ps
docker compose logs gitea-db
```

The MySQL container may take a few seconds to initialize on first run.

### Gitea SSH not working

Make sure port 2222 is not blocked and use the correct SSH URL format:

```bash
git clone ssh://git@localhost:2222/<username>/<repo>.git
```
