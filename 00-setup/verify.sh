#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0
SERVER_URL="${OSB_SERVER_URL:-http://localhost:8080}"

check() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "  [OK]  $label"
    ((PASS++)) || true
  else
    echo "  [FAIL] $label"
    ((FAIL++)) || true
  fi
}

echo ""
echo "==> Verifying OpenSandbox tutorial prerequisites"
echo ""

check "Docker is running"              "docker info"
check "kubectl is available"           "kubectl version --client"
check "Python 3.11+"                   "python --version | grep -E '3\.(11|12|13)'"
check "uv is available"                "uv --version"
check "opensandbox SDK installed"      "python -c 'import opensandbox'"
check "opensandbox-server installed"   "opensandbox-server --help"
check "Server reachable at $SERVER_URL" "curl -sf $SERVER_URL/health"

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "All checks passed. You're ready to go!"
else
  echo "$FAIL check(s) failed."
  if curl -sf "$SERVER_URL/health" &>/dev/null; then true; else
    echo ""
    echo "  Server not running? Start it with: make serve"
  fi
  exit 1
fi
