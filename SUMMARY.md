# OpenSandbox Brownbag — Companion Notes

---

## What is OpenSandbox?

Fully self-hosted sandbox runtime by Alibaba. Each sandbox is a Docker container. No cloud, no API key.

```
your code  →  opensandbox SDK  →  opensandbox-server  →  Docker / K8s
```

`opensandbox-server` is a **persistent service**, not a per-request process. In production you deploy it once (systemd, K8s deployment, etc.) and all SDK clients connect to it by domain. In this tutorial we run it with `make serve` just to keep setup minimal — but the SDK usage is identical either way.

---

## Why sandboxes?

The pattern shows up whenever you need to run untrusted or arbitrary code safely:

- **LLM code interpreter** — model generates Python, you execute it in a sandbox, return stdout
- **CI / test runners** — each test run gets a clean, isolated container; no shared state between jobs
- **User-submitted scripts** — SaaS platforms that let users upload and run their own automation
- **Batch data processing** — fan out the same workload across N sandboxes in parallel (the K8s Pool story)

OpenSandbox gives you a managed API for all of these instead of shelling out to `docker run` yourself.

---

## Production vs. this tutorial

| | Tutorial (`make serve`) | Production |
|---|---|---|
| Server | Local process, foreground | Persistent service (systemd / K8s deployment) |
| Auth | Disabled (`OPENSANDBOX_INSECURE_SERVER=YES`) | API key in `sandbox.toml` |
| Docker backend | Colima on your laptop | Docker daemon on a VM or K8s node |
| SDK config | `domain="localhost:8080"` | `domain="sandboxes.yourcompany.internal"` |

The SDK code is identical — only `ConnectionConfig(domain=...)` changes.

---

## Setup (before the session)

```bash
make setup     # install deps + generate sandbox.toml
make serve     # Terminal A — keep open
make verify    # Terminal B — confirm all green
```

**macOS / Colima:** must use the Docker runtime, not containerd.
```bash
colima start --runtime docker
```

---

## Exercises

| # | What it shows |
|---|---|
| 01-basics | Create sandbox → run commands → stream output live |
| 02-files | Write script into sandbox → execute → read result back |
| 03-run-python | Copy local `.py` file into sandbox → run → pip install stays isolated |
| 04-egress | Network policy at creation time — allowlist two domains, block everything else |
| 05-mcp | Drive sandboxes via MCP protocol; `.mcp.json` wires Claude Code automatically |
| 06-k8s | Pool pre-warms pods; tasks dispatch in <1s with no cold start |

---

## Key gotchas

- **Colima must use Docker backend** — containerd/nerdctl breaks the server socket
- **`result.output` doesn't exist** — use `result.logs.stdout[0].text`
- **Streaming `msg.text` has no `\n`** — always `rstrip("\n")` before printing
- **Helm chart namespace is hardcoded** — always pass `--namespace opensandbox-system --create-namespace`
