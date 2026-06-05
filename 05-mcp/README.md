# 05-mcp — OpenSandbox via MCP

Starts the `opensandbox-mcp` server and talks to it using the MCP protocol — the same interface Claude Code uses internally. Creates a sandbox, runs a command, kills it, all over MCP.

```bash
make run-05
```

## What you'll see

```
=== MCP tools exposed by opensandbox-mcp ===
  sandbox_create
  sandbox_kill
  command_run
  file_write
  ... (19 tools total)

==> sandbox_create
    sandbox_id: <id>
    state:      running

==> command_run  (uname -a)
    Linux ... aarch64 GNU/Linux

==> command_run  (python3)
    Python 3.12.x — via MCP

==> sandbox_kill
    killed: <id>
```

## Claude Code integration

This repo ships `.mcp.json` at the root. Claude Code auto-discovers it when you open this folder. With `make serve` running, Claude can create sandboxes and run commands directly from a chat prompt — no configuration needed.

Try asking Claude: *"Create a sandbox and run `df -h`"*

## Key API

```python
from mcp import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

SERVER = StdioServerParameters(command="uv",
    args=["run", "opensandbox-mcp", "--domain", "localhost:8080", "--protocol", "http"])

async with stdio_client(SERVER) as (read, write):
    async with ClientSession(read, write) as session:
        await session.initialize()
        result = await session.call_tool("sandbox_create", {"image": "python:3.12"})
        sandbox_id = json.loads(result.content[0].text)["sandbox_id"]
```
