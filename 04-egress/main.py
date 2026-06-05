"""04-egress solution: sandbox with allow/deny network egress policy."""
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

PROBES = [
    ("https://api.github.com/zen",        "allowed"),
    ("https://pypi.org/simple/requests/", "allowed"),
    ("https://httpbin.org/get",           "denied"),
    ("https://example.com",               "denied"),
]


async def probe(sandbox: Sandbox, url: str, expected: str) -> None:
    execution = await sandbox.commands.run(
        f"curl -s --max-time 3 -o /dev/null -w '%{{http_code}}' {url} 2>/dev/null || echo 000"
    )
    code = "".join(m.text for m in execution.logs.stdout).strip() if execution.logs.stdout else "000"
    blocked = not code or code.startswith("0")
    outcome = "denied" if blocked else "allowed"
    status  = "blocked" if blocked else f"{code} OK"
    mark    = "✓" if outcome == expected else "✗ UNEXPECTED"
    print(f"  {url:<50} → {status:<10} ({expected}) {mark}")


async def main() -> None:
    policy = NetworkPolicy(
        defaultAction="deny",
        egress=[
            NetworkRule(action="allow", target="api.github.com"),
            NetworkRule(action="allow", target="pypi.org"),
        ],
    )

    sandbox = await Sandbox.create(
        "python:3.12",
        connection_config=config,
        timeout=timedelta(minutes=10),
        network_policy=policy,
    )

    async with sandbox:
        print(f"[sandbox] created: {sandbox.id}  (egress: allowlist)\n")
        print("Probing egress rules...")
        for url, expected in PROBES:
            await probe(sandbox, url, expected)
        await sandbox.kill()
    print(f"\n[sandbox] killed: {sandbox.id}")


if __name__ == "__main__":
    asyncio.run(main())
