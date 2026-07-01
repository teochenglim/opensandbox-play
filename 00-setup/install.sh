#!/usr/bin/env bash
set -euo pipefail

echo "==> Setting up OpenSandbox tutorial environment"

# ── K8s CRDs (optional, skip if kubectl/helm unavailable) ─────────────────────
if command -v kubectl &>/dev/null && command -v helm &>/dev/null; then
  echo ""
  echo "==> Installing OpenSandbox K8s controller + CRDs..."
  if helm status opensandbox-controller -n opensandbox-system &>/dev/null 2>&1; then
    echo "    Controller already installed — skipping."
  else
    helm install opensandbox-controller \
      https://github.com/alibaba/OpenSandbox/releases/download/helm/opensandbox-controller/0.1.0/opensandbox-controller-0.1.0.tgz \
      --namespace opensandbox-system --create-namespace
    echo "    Waiting for controller to be ready..."
    kubectl rollout status deployment -n opensandbox-system --timeout=120s 2>/dev/null || true
  fi
  echo "    CRDs installed:"
  kubectl get crd | grep opensandbox | awk '{print "    -", $1}' || true
else
  echo "    [SKIP] kubectl/helm not found — K8s exercise (06-k8s) will be unavailable."
fi

# ── Python deps ───────────────────────────────────────────────────────────────
echo ""
echo "==> Syncing Python dependencies..."
if ! command -v uv &>/dev/null; then
  echo "ERROR: uv not found. Install from https://docs.astral.sh/uv/getting-started/installation/"
  exit 1
fi
uv sync

# ── Server config ─────────────────────────────────────────────────────────────
echo ""
echo "==> Generating local server config (sandbox.toml)..."
if [[ -f sandbox.toml ]]; then
  echo "    sandbox.toml already exists — skipping."
else
  cp 00-setup/sandbox.docker.toml sandbox.toml
  echo "    Config written to ./sandbox.toml"
fi

# ── Server image ──────────────────────────────────────────────────────────────
echo ""
echo "==> Pulling opensandbox/server:latest (if not present)..."
docker image inspect opensandbox/server:latest &>/dev/null || docker pull opensandbox/server:latest

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Terminal A: make serve          # start the server (Docker container, foreground)"
echo "  2. Terminal B: make verify         # confirm everything is up"
echo "  3. Terminal B: make run-01         # run first exercise"
