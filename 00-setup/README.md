# 00-setup — Local Server + Environment Verification

No coding here — just getting the local OpenSandbox server running.

## What runs locally

OpenSandbox is **fully self-hosted**. There is no cloud API key required.

- `opensandbox/server` — FastAPI control plane image, runs as a Docker container, manages sandbox containers via the same Docker daemon
- `opensandbox` SDK — Python client that talks to the local server over HTTP
- Sandboxes are just Docker containers on your machine, siblings of the server container

## Steps

### 1. Install everything

```bash
bash 00-setup/install.sh
# or:
make setup
```

This: installs K8s CRDs (if kubectl+helm available) → syncs uv deps → generates `./sandbox.toml`.

### 2. Start the server (keep this terminal open)

```bash
make serve
# or directly:
docker run --rm --name opensandbox-server \
  -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)/sandbox.toml:/etc/opensandbox/config.toml:ro" \
  -e SANDBOX_CONFIG_PATH=/etc/opensandbox/config.toml \
  -e OPENSANDBOX_INSECURE_SERVER=YES \
  opensandbox/server:latest
```

Server starts at `http://localhost:8080`. Verify: `curl http://localhost:8080/health`

### 3. Verify in a second terminal

```bash
make verify
# or:
bash 00-setup/verify.sh
```

## Expected output

```
==> Verifying OpenSandbox tutorial prerequisites

  [OK]  Docker is running
  [OK]  kubectl is available
  [OK]  Python 3.11+
  [OK]  uv is available
  [OK]  opensandbox SDK installed
  [OK]  opensandbox/server image pulled
  [OK]  Server reachable at http://localhost:8080

All checks passed. You're ready to go!
```

## Troubleshooting

| Failure | Fix |
|---|---|
| Server not reachable | Run `make serve` in a separate terminal |
| Docker not running | Start Docker Desktop or `sudo systemctl start docker` |
| opensandbox SDK missing | `uv sync` from repo root |
| Python 3.11+ | uv manages Python — no pyenv needed |
| macOS Colima: server can't find Docker | Colima must use Docker runtime: `colima start --runtime docker` |

## Server config (`./sandbox.toml`)

Generated locally by `make setup` (copied from [`00-setup/sandbox.docker.toml`](sandbox.docker.toml)) and gitignored. The default config works for all exercises. To inspect:

```bash
cat sandbox.toml
```

No API key is needed — local mode skips auth entirely.
