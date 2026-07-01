"""04-egress: before/after showing egress block in action."""
import asyncio
import os
from datetime import timedelta

from opensandbox import Sandbox
from opensandbox.config import ConnectionConfig
from opensandbox.models.sandboxes import NetworkPolicy

config = ConnectionConfig(
    domain=os.getenv("SANDBOX_DOMAIN", "localhost:8080"),
    api_key=os.getenv("SANDBOX_API_KEY"),
    request_timeout=timedelta(seconds=60),
)

TARGET = "https://api.github.com/zen"


async def curl(sandbox: Sandbox, url: str) -> str:
    execution = await sandbox.commands.run(
        f"curl -s --max-time 3 -o /dev/null -w '%{{http_code}}' {url} 2>/dev/null || echo 000"
    )
    return "".join(m.text for m in execution.logs.stdout).strip() if execution.logs.stdout else "000"


async def main() -> None:
    # --- without policy ---
    print("1) No egress policy (default: allow all)")
    sandbox = await Sandbox.create("python:3.12", connection_config=config, timeout=timedelta(minutes=5))
    async with sandbox:
        code = await curl(sandbox, TARGET)
        print(f"   curl {TARGET}")
        print(f"   → {code} {'✓ reachable' if not code.startswith('0') else '✗ blocked'}\n")

    # --- with deny-all policy ---
    print("2) Egress policy: deny all  (may take ~40s on first run to pull egress image)")
    policy = NetworkPolicy(defaultAction="deny", egress=[])
    sandbox = await Sandbox.create(
        "python:3.12",
        connection_config=config,
        timeout=timedelta(minutes=5),
        network_policy=policy,
    )
    async with sandbox:
        code = await curl(sandbox, TARGET)
        print(f"   curl {TARGET}")
        print(f"   → {code} {'✓ reachable' if not code.startswith('0') else '✗ blocked'}\n")

    print("Same URL, same command — policy is the only difference.")


if __name__ == "__main__":
    asyncio.run(main())
