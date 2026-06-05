# OpenSandbox Brownbag — Companion Notes

---

## What is OpenSandbox?

Fully self-hosted sandbox runtime by Alibaba. Each sandbox is a Docker container. No cloud, no API key.

```
your code  →  opensandbox SDK  →  opensandbox-server  →  Docker / K8s
```

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
