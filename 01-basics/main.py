"""01-basics solution: sandbox lifecycle, command execution, and streaming output."""
import asyncio
import os
from datetime import timedelta

from opensandbox import Sandbox
from opensandbox.config import ConnectionConfig
from opensandbox.models.execd import ExecutionHandlers

config = ConnectionConfig(
    domain=os.getenv("SANDBOX_DOMAIN", "localhost:8080"),
    api_key=os.getenv("SANDBOX_API_KEY"),
    request_timeout=timedelta(minutes=5),
)


async def create_with_progress() -> Sandbox:
    """Create the sandbox, printing a heartbeat so a slow first run (image pulls) isn't silent."""
    print("[sandbox] creating (first run pulls python:3.12 + execd images, may take 1-2 min)...", flush=True)
    task = asyncio.create_task(
        Sandbox.create(
            "python:3.12",
            connection_config=config,
            timeout=timedelta(minutes=10),
            ready_timeout=timedelta(minutes=5),  # default 30s is too short for a cold image pull
        )
    )
    elapsed = 0
    while not task.done():
        await asyncio.wait({task}, timeout=5)
        elapsed += 5
        if not task.done():
            print(f"[sandbox] still creating... {elapsed}s", flush=True)
    return task.result()


async def main() -> None:
    sandbox = await create_with_progress()

    async with sandbox:
        print(f"[sandbox] created: {sandbox.id}")

        print("\n[run] uname -a")
        execution = await sandbox.commands.run("uname -a")
        stdout = execution.logs.stdout[0].text if execution.logs.stdout else ""
        print(stdout.strip())

        print("\n[run] python3 --version")
        execution = await sandbox.commands.run("python3 --version")
        stdout = execution.logs.stdout[0].text if execution.logs.stdout else ""
        print(stdout.strip())

        print("\n[stream] counting to 5...")

        async def on_stdout(msg):
            print(msg.text.rstrip("\n"), flush=True)

        handlers = ExecutionHandlers(on_stdout=on_stdout)
        await sandbox.commands.run(
            "for i in $(seq 1 5); do echo $i; sleep 0.3; done",
            handlers=handlers,
        )
        print("[stream] done.")

        await sandbox.kill()
    print(f"\n[sandbox] killed: {sandbox.id}")


if __name__ == "__main__":
    asyncio.run(main())
