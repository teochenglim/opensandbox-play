"""03-run-python: copy a local script into the sandbox and run it there."""
import asyncio
import os
from datetime import timedelta
from pathlib import Path

from opensandbox import Sandbox
from opensandbox.config import ConnectionConfig
from opensandbox.models.filesystem import WriteEntry

HERE = Path(__file__).parent
SCRIPT = HERE / "script.py"
REMOTE = "/tmp/script.py"

config = ConnectionConfig(
    domain=os.getenv("SANDBOX_DOMAIN", "localhost:8080"),
    api_key=os.getenv("SANDBOX_API_KEY"),
    request_timeout=timedelta(seconds=60),
)


async def main() -> None:
    sandbox = await Sandbox.create(
        "python:3.12",
        connection_config=config,
        timeout=timedelta(minutes=10),
    )

    async with sandbox:
        print(f"[sandbox] created: {sandbox.id}")

        # Copy local script.py into the sandbox
        print(f"\n[upload] {SCRIPT.name} → {REMOTE}")
        await sandbox.files.write_files([WriteEntry(path=REMOTE, data=SCRIPT.read_text())])

        # Run it
        print("[run] python3 /tmp/script.py")
        execution = await sandbox.commands.run(f"python3 {REMOTE}")
        output = "\n".join(m.text.rstrip("\n") for m in execution.logs.stdout)
        print(output)

        # Prove isolation: install inside sandbox, not on host
        print("\n[pip install] requests — inside the sandbox only")
        await sandbox.commands.run("pip install requests -q")
        check = await sandbox.commands.run(
            "python3 -c \"import requests; print('requests', requests.__version__)\""
        )
        print("\n".join(m.text.rstrip("\n") for m in check.logs.stdout))

        await sandbox.kill()
    print(f"\n[sandbox] killed: {sandbox.id}")


if __name__ == "__main__":
    asyncio.run(main())
