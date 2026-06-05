Create a hands-on OpenSandbox tutorial git repo for a brownbag audience 
(senior engineers, 45 min session). Repo should be self-contained and 
runnable locally with just Docker + Python 3.11+.

Structure:
- README.md — clear quick-start, what they'll learn, prereqs
- 00-setup/        — install script + verify script (checks Docker, pip, osb CLI)
- 01-basics/       — create sandbox, run commands, stream output via SSE
- 02-files/        — upload/download files, execute a script inside sandbox
- 03-code-interp/  — run Python + Node inside sandbox via code interpreter SDK
- 04-egress/       — create sandbox with egress policy, test allow/deny rules
- 05-mcp/          — wire opensandbox-mcp to a Claude Code config, sample prompt
- 06-k8s/          — BatchSandbox manifest + Pool CRD yaml (K8s optional path)
- solutions/       — complete working versions of all exercises

Each exercise:
- Has a README with the goal, the gap to fill (// TODO), and expected output
- Uses a __main__.py or shell script so `python exercise.py` just works
- Ends with a "stretch goal" one-liner for fast finishers

Make the exercises progressive — each builds on the previous sandbox pattern.
Add a Makefile at root: make setup, make run-all, make clean.
Use real opensandbox SDK calls (alibaba/OpenSandbox Python SDK).
Keep code idiomatic — no unnecessary abstractions, direct and readable.