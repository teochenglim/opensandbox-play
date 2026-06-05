"""02-files solution: write a script into the sandbox, run it, read the result back."""
import asyncio
import os
import pathlib
from datetime import timedelta

from opensandbox import Sandbox
from opensandbox.config import ConnectionConfig
from opensandbox.models.filesystem import WriteEntry

config = ConnectionConfig(
    domain=os.getenv("SANDBOX_DOMAIN", "localhost:8080"),
    api_key=os.getenv("SANDBOX_API_KEY"),
    request_timeout=timedelta(seconds=60),
)

LOCAL_SCRIPT  = pathlib.Path(__file__).parent / "scripts" / "analyze.py"
REMOTE_SCRIPT = "/workspace/analyze.py"
REMOTE_REPORT = "/workspace/report.txt"
LOCAL_REPORT  = pathlib.Path("downloaded_report.txt")


async def main() -> None:
    sandbox = await Sandbox.create(
        "python:3.12",
        connection_config=config,
        timeout=timedelta(minutes=10),
    )

    async with sandbox:
        print(f"[sandbox] created: {sandbox.id}")

        print(f"\n[upload] {LOCAL_SCRIPT.name} → {REMOTE_SCRIPT}")
        await sandbox.files.write_files([
            WriteEntry(path=REMOTE_SCRIPT, data=LOCAL_SCRIPT.read_text())
        ])

        print(f"\n[run] python3 {REMOTE_SCRIPT}")
        execution = await sandbox.commands.run(f"python3 {REMOTE_SCRIPT}")
        out = "".join(m.text for m in execution.logs.stdout) if execution.logs.stdout else ""
        for line in out.splitlines():
            print(f"  {line}")

        print(f"\n[download] {REMOTE_REPORT} → {LOCAL_REPORT}")
        content = await sandbox.files.read_file(REMOTE_REPORT)
        LOCAL_REPORT.write_text(content)

        print(f"\n[result] {LOCAL_REPORT}:")
        for line in LOCAL_REPORT.read_text().splitlines():
            print(f"  {line}")

        await sandbox.kill()
    print(f"\n[sandbox] killed: {sandbox.id}")


if __name__ == "__main__":
    asyncio.run(main())
