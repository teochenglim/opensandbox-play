# 01-basics — Create, Run, Stream

Creates a sandbox, runs two shell commands, then streams a counting loop line by line.

```bash
make run-01
```

## What you'll see

```
[sandbox] created: <id>
[run] uname -a
Linux ... aarch64 GNU/Linux
[run] python3 --version
Python 3.12.x
[stream] counting to 5...
1
2
3
4
5
[stream] done.
[sandbox] killed: <id>
```

The numbers arrive one at a time with a 0.3s gap — that's streaming. Without it you'd wait for the full command to finish before seeing anything.

## Key API

```python
sandbox = await Sandbox.create("python:3.12", connection_config=config, timeout=timedelta(minutes=10))

result = await sandbox.commands.run("uname -a")
print(result.logs.stdout[0].text)

handlers = ExecutionHandlers(on_stdout=lambda msg: print(msg.text.rstrip("\n"), flush=True))
await sandbox.commands.run("for i in $(seq 1 5); do echo $i; sleep 0.3; done", handlers=handlers)
```

## Try it

Change the Docker image from `python:3.12` to `ubuntu:22.04` in `main.py` and re-run. The sandbox pulls a different image and you get a different environment.
