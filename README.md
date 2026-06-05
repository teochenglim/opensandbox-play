# OpenSandbox Tutorial

Six runnable exercises showing what OpenSandbox can do — all local, no cloud account, no API key.

Each exercise is a single `make run-NN` command. You watch it run, read the code, understand the pattern.

---

## Before you start

### What you need

| Requirement | Why |
|---|---|
| Docker running | Sandboxes are Docker containers |
| `uv` installed | Manages Python deps (`curl -LsSf https://astral.sh/uv/install.sh \| sh`) |
| `kubectl` + `helm` | Only for exercise 06 — skip if you don't have K8s |

### macOS with Colima — read this first

OpenSandbox talks to Docker via the Docker socket, not via `nerdctl`. If you use Colima with the default containerd backend, the server will fail with a socket-not-found error.

Fix: switch Colima to the Docker runtime before starting.

```bash
colima stop
colima start --runtime docker
```

`make serve` automatically sets `DOCKER_HOST` to the Colima socket — you don't need to do anything else.

---

## Setup

```bash
# Install deps + generate local server config
make setup

# Terminal A — keep this open the whole session
make serve

# Terminal B — confirm everything is working
make verify
```

`make verify` checks Docker, the server health endpoint, and that the SDK is importable. If it passes, you're ready.

---

## Running the exercises

```bash
make run-01   # basics
make run-02   # files
make run-03   # run python
make run-04   # egress
make run-05   # mcp
make run-06   # k8s (requires kubectl + helm)

make run-all  # all six in sequence
```

Each exercise prints what it's doing step by step. Read the corresponding `main.py` alongside — the code matches the output line for line.

---

## What each exercise shows

**01-basics** — You create a sandbox, run a shell command, get back the output. Then you run a loop that prints 1–5 with a delay and watch the lines arrive one at a time (streaming). This is the full sandbox lifecycle in ~30 lines.

**02-files** — You write a local Python script into the sandbox filesystem, execute it there, then read back the file it produced. The sandbox's filesystem is isolated from yours until you explicitly read a file out.

**03-run-python** — You copy `script.py` into the sandbox and run it. Then you `pip install requests` inside the sandbox and verify it's not installed on your host. This is the pattern that powers LLM code-interpreter features.

**04-egress** — You create a sandbox with a network policy: `api.github.com` and `pypi.org` are allowed, everything else is blocked. The exercise probes four URLs and you see two succeed and two fail. Policy is set at creation time and can't be changed after.

**05-mcp** — The exercise starts an MCP server (`opensandbox-mcp`) as a subprocess and calls it using the same MCP protocol Claude Code uses. You see the 19 tools it exposes, then watch a sandbox get created and a command run — all over MCP. The `.mcp.json` in this repo is auto-discovered by Claude Code: open this folder in Claude Code with `make serve` running and Claude can create sandboxes directly.

**06-k8s** — Creates a `Pool` of pre-warmed K8s pods, then dispatches tasks into three of them via `kubectl exec`. The point: the pods are already running before you ask, so task dispatch is nearly instant. `BatchSandbox` is the CRD that manages bulk allocation from the pool.

---

## Common problems

**`make serve` fails with "cannot connect to Docker"**
Docker isn't running, or (macOS/Colima) you're using the containerd backend. See the Colima note above.

**`make verify` shows server not reachable**
`make serve` isn't running, or it's still starting up. Give it 3–5 seconds and try again.

**Exercise fails with port-already-in-use**
A previous sandbox container didn't clean up. Restart the server (`make stop && make serve-bg`) or wait a few seconds and retry.

**`make run-06` — no kubectl or helm**
Skip it. Exercises 01–05 don't need K8s at all.

**`make run-06` — pool pods not coming up**
K8s node may be under resource pressure. Check `kubectl get pods -A` for pending pods. The pool requests 250m CPU and 256Mi RAM per pod.
