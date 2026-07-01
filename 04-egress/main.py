"""04-egress solution: allowlist network policy, probe reachable vs blocked URLs."""
import asyncio
import os
from datetime import timedelta

from opensandbox import Sandbox
from opensandbox.config import ConnectionConfig
from opensandbox.models.sandboxes import NetworkPolicy, NetworkRule

config = ConnectionConfig(
    domain=os.getenv("SANDBOX_DOMAIN", "localhost:8080"),
    api_key=os.getenv("SANDBOX_API_KEY"),
    request_timeout=timedelta(seconds=60),
)

URLS = [
    "https://api.github.com/zen",
    "https://pypi.org/simple/requests/",
    "https://httpbin.org/get",
    "https://example.com",
]

POLICY = NetworkPolicy(
    defaultAction="deny",
    egress=[
        NetworkRule(action="allow", target="api.github.com"),
        NetworkRule(action="allow", target="pypi.org"),
    ],
)


async def curl(sandbox: Sandbox, url: str) -> str:
    execution = await sandbox.commands.run(
        f"curl -s --max-time 3 -o /dev/null -w '%{{http_code}}' {url} 2>/dev/null || echo 000"
    )
    return "".join(m.text for m in execution.logs.stdout).strip() if execution.logs.stdout else "000"


async def main() -> None:
    sandbox = await Sandbox.create(
        "python:3.12",
        connection_config=config,
        timeout=timedelta(minutes=5),
        network_policy=POLICY,
    )

    async with sandbox:
        print(f"[sandbox] created: {sandbox.id}  (egress: allowlist)")

        print("Probing egress rules...")
        for url in URLS:
            code = await curl(sandbox, url)
            reachable = not code.startswith("0")
            status = f"{code} OK" if reachable else "blocked"
            verdict = "(allowed) ✓" if reachable else "(denied)  ✓"
            print(f"  {url:<40} → {status:<10} {verdict}")

        await sandbox.kill()
    print(f"[sandbox] killed: {sandbox.id}")


if __name__ == "__main__":
    asyncio.run(main())
