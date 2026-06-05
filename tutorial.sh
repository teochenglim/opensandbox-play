#!/usr/bin/env bash
# OpenSandbox CLI Walkthrough — brownbag facilitator script
# Run this top-to-bottom; each section narrates what the audience sees.
set -euo pipefail

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

step()  { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo -e "${BOLD}$*${RESET}"; }
note()  { echo -e "${YELLOW}  $*${RESET}"; }
ok()    { echo -e "${GREEN}  ✓ $*${RESET}"; }
pause() { echo -e "\n${BOLD}[press ENTER to continue]${RESET}"; read -r; }

# ─── 0. Setup ─────────────────────────────────────────────────────────────────

step "0 / 6  — Setup: local server + Python tooling"
note "Everything runs locally. No API key needed."
note "macOS / Colima users: Colima must use the Docker runtime (not containerd/nerdctl)."
note "  colima start --runtime docker"

cat <<'DEMO'

  # Install deps + K8s CRDs (if kubectl/helm available) + generate sandbox.toml
  bash 00-setup/install.sh
  # or:
  make setup

  # Terminal A — keep this running the whole session
  make serve
  #  → server at http://localhost:8080

  # Terminal B — confirm all checks pass
  make verify

DEMO

note "The server is a FastAPI process that spins sandboxes as Docker containers."
note "Swagger UI: http://localhost:8080/docs"
pause

# ─── 1. Basics ────────────────────────────────────────────────────────────────

step "1 / 6  — Basics: create, exec, stream"
note "A sandbox = a Docker container. Creation takes ~1 s. We use 'async with' for cleanup."

cat <<'DEMO'

  # Key API:
  sandbox = await Sandbox.create("python:3.12", connection_config=config,
                                  timeout=timedelta(minutes=10))
  async with sandbox:
      result = await sandbox.commands.run("uname -a")
      stdout = result.logs.stdout[0].text

      # Streaming output
      async def on_stdout(msg):
          print(msg.text.rstrip("\n"), flush=True)
      handlers = ExecutionHandlers(on_stdout=on_stdout)
      await sandbox.commands.run("for i in $(seq 1 5); do echo $i; sleep 0.3; done",
                                  handlers=handlers)

DEMO

echo "  make run-01"
note "Watch the counter arrive one line at a time — that's HTTP streaming."
pause

# ─── 2. Files ─────────────────────────────────────────────────────────────────

step "2 / 6  — Files: write → exec → read"
note "Sandboxes start empty. Push code in with write_files, pull results with read_file."

cat <<'DEMO'

  from opensandbox.models.filesystem import WriteEntry

  # Upload a local script into the sandbox
  await sandbox.files.write_files([WriteEntry(path="/workspace/analyze.py",
                                               data=Path("analyze.py").read_text())])

  # Execute it
  execution = await sandbox.commands.run("python3 /workspace/analyze.py")

  # Read an output file back
  content = await sandbox.files.read_file("/workspace/report.txt")
  Path("downloaded_report.txt").write_text(content)

DEMO

echo "  make run-02"
echo "  cat downloaded_report.txt"
note "Sandbox filesystem is isolated — your local files are untouched until you read them out."
pause

# ─── 3. Run Python ────────────────────────────────────────────────────────────

step "3 / 6  — Run Python: arbitrary code in isolation"
note "Write a Python string → write_files → python3 → read stdout. Simple, safe, no escaping."

cat <<'DEMO'

  async def run_code(sandbox, code: str) -> str:
      await sandbox.files.write_files([WriteEntry(path="/tmp/script.py", data=code)])
      execution = await sandbox.commands.run("python3 /tmp/script.py")
      return "\n".join(m.text.rstrip("\n") for m in execution.logs.stdout)

  # Each call is isolated — installs don't leak between runs
  await sandbox.commands.run("pip install -q numpy")
  result = await run_code(sandbox, "import numpy as np; print(np.random.randn(5))")

DEMO

echo "  make run-03"
note "Same pattern powers LLM 'code interpreter' features — safe, disposable, repeatable."
pause

# ─── 4. Egress ────────────────────────────────────────────────────────────────

step "4 / 6  — Egress: network allow/deny policies"
note "Lock down per-sandbox at creation time. Default=deny + allowlist."

cat <<'DEMO'

  from opensandbox.models.sandboxes import NetworkPolicy, NetworkRule

  policy = NetworkPolicy(
      defaultAction="deny",
      egress=[
          NetworkRule(action="allow", target="api.github.com"),
          NetworkRule(action="allow", target="pypi.org"),
      ],
  )
  sandbox = await Sandbox.create("python:3.12", connection_config=config,
                                  timeout=timedelta(minutes=10),
                                  network_policy=policy)

DEMO

echo "  make run-04"
note "github + pypi → 200 OK; everything else → connection refused."
pause

# ─── 5. MCP ───────────────────────────────────────────────────────────────────

step "5 / 6  — MCP: sandboxes as Claude Code tools"
note "opensandbox-mcp exposes 19 tools (sandbox_create, command_run, ...) over stdio."
note "The repo already has .mcp.json — Claude Code auto-discovers it when you open this folder."

cat <<'DEMO'

  # .mcp.json (already committed):
  {
    "mcpServers": {
      "opensandbox": {
        "command": "uv",
        "args": ["run", "opensandbox-mcp", "--domain", "localhost:8080", "--protocol", "http"]
      }
    }
  }

  # Python MCP client (same protocol Claude Code uses internally):
  from mcp import ClientSession
  from mcp.client.stdio import StdioServerParameters, stdio_client

  async with stdio_client(SERVER) as (read, write):
      async with ClientSession(read, write) as session:
          await session.initialize()
          tools = await session.list_tools()        # 19 tools
          result = await session.call_tool("sandbox_create", {"image": "python:3.12"})
          sandbox_id = json.loads(result.content[0].text)["sandbox_id"]
          await session.call_tool("command_run", {"sandbox_id": sandbox_id, "command": "uname -a"})
          await session.call_tool("sandbox_kill", {"sandbox_id": sandbox_id})

DEMO

echo "  make run-05"
note "In Claude Code: tell Claude 'create a sandbox and run df -h' — it calls the tools automatically."
pause

# ─── 6. K8s ───────────────────────────────────────────────────────────────────

step "6 / 6  — K8s: Pool + BatchSandbox"
note "Pool keeps N warm standby pods ready. BatchSandbox allocates replicas from the pool in O(1)."
note "Controller already installed if you ran make setup / install.sh."

cat <<'DEMO'

  # Pool — pre-warm 2–10 sandboxes
  kubectl apply -f 06-k8s/sandbox-pool.yaml
  kubectl get pool tutorial-pool -w

  # BatchSandbox — allocate 3 replicas, each runs a different word-count task
  kubectl apply -f 06-k8s/batch-sandbox.yaml
  kubectl get batchsandbox word-count -w

  # Clean up
  make clean-06

DEMO

echo "  make run-06"
note "The pool makes BatchSandbox allocation instantaneous — no cold-start wait."
pause

# ─── Wrap-up ──────────────────────────────────────────────────────────────────

step "Wrap-up"

echo ""
echo "  What you built today:"
ok "Local OpenSandbox server — no cloud account needed"
ok "Sandbox lifecycle — create / exec / stream / kill  (async Python SDK)"
ok "File write/read — push code in, pull results out"
ok "Isolated Python execution — safe code interpreter pattern"
ok "Network egress allow/deny policies — per-sandbox at creation time"
ok "Claude Code MCP integration — .mcp.json in the repo"
ok "K8s Pool + BatchSandbox — warm standby + O(1) bulk allocation"
echo ""
echo "  Stretch goals:"
echo "    01: set timeout=timedelta(seconds=3), run a slow command → observe error"
echo "    02: write 20 files in one write_files call vs. 20 individual calls"
echo "    03: pip install inside sandbox, use it in the next run_code call"
echo "    04: flip to defaultAction=allow + denylist, test an unlisted URL"
echo "    05: ask Claude Code (with .mcp.json) to 'pip install pandas and plot a chart'"
echo "    06: add more replicas to BatchSandbox, watch the pool auto-scale"
echo ""
