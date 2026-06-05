"""05-mcp: drive opensandbox via MCP tools — same interface Claude Code uses."""
import asyncio
import json

from mcp import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

SERVER = StdioServerParameters(
    command="uv",
    args=["run", "opensandbox-mcp", "--domain", "localhost:8080", "--protocol", "http"],
)


async def main() -> None:
    async with stdio_client(SERVER) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # List available tools
            tools = await session.list_tools()
            print("=== MCP tools exposed by opensandbox-mcp ===")
            for t in tools.tools:
                print(f"  {t.name}")

            # Create a sandbox via MCP
            print("\n==> sandbox_create")
            result = await session.call_tool(
                "sandbox_create",
                {"image": "python:3.12", "timeout_seconds": 120},
            )
            data = json.loads(result.content[0].text)
            sandbox_id = data["sandbox_id"]
            print(f"    sandbox_id: {sandbox_id}")
            print(f"    state:      {data['info']['status']['state']}")

            try:
                # Run a command
                print("\n==> command_run  (uname -a)")
                result = await session.call_tool(
                    "command_run",
                    {"sandbox_id": sandbox_id, "command": "uname -a"},
                )
                logs = json.loads(result.content[0].text)["logs"]["stdout"]
                print(f"    {''.join(m['text'] for m in logs).strip()}")

                # Run Python
                print("\n==> command_run  (python3)")
                result = await session.call_tool(
                    "command_run",
                    {
                        "sandbox_id": sandbox_id,
                        "command": "python3 -c \"import sys; print('Python', sys.version.split()[0], '— via MCP')\"",
                    },
                )
                logs = json.loads(result.content[0].text)["logs"]["stdout"]
                print(f"    {''.join(m['text'] for m in logs).strip()}")

            finally:
                print(f"\n==> sandbox_kill")
                await session.call_tool("sandbox_kill", {"sandbox_id": sandbox_id})
                print(f"    killed: {sandbox_id}")


if __name__ == "__main__":
    asyncio.run(main())
