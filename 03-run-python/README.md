# 03-run-python — Copy a Script, Run It, Read Stdout

Copies `script.py` from your machine into the sandbox, executes it with Python, and captures stdout. Then proves isolation by pip-installing `requests` inside the sandbox only.

```bash
make run-03
```

## What you'll see

```
[sandbox] created: <id>
[upload] script.py → /tmp/script.py
[run] python3 /tmp/script.py
[
  {"word": "opensandbox", "hash": "dee127c2", "len": 11},
  ...
]
Python 3.12.x — running inside the sandbox!

[pip install] requests — inside the sandbox only
requests 2.x.x
[sandbox] killed: <id>
```

After the sandbox is killed, `requests` is gone. Nothing was installed on your machine.

## Key API

```python
await sandbox.files.write_files([WriteEntry(path="/tmp/script.py", data=Path("script.py").read_text())])
execution = await sandbox.commands.run("python3 /tmp/script.py")
output = "\n".join(m.text.rstrip("\n") for m in execution.logs.stdout)
```

## Try it

Edit `script.py` directly — it's a real file. Change the word list, add more computation, import a stdlib module. Re-run `make run-03` and see your changes execute inside the sandbox.
