# 02-files — Write, Execute, Read

Writes a local Python script into the sandbox filesystem, runs it there, then reads back the output file it produced.

```bash
make run-02
```

## What you'll see

```
[sandbox] created: <id>
[upload] analyze.py → /workspace/analyze.py
[run] python3 /workspace/analyze.py
    Lines processed: 100  Words: 863  Unique words: 15
[download] /workspace/report.txt → downloaded_report.txt
[result] downloaded_report.txt:
  === Analysis Report ===
  Lines: 100  Words: 863  Unique: 15
[sandbox] killed: <id>
```

The sandbox filesystem is completely isolated — your local files are untouched until you explicitly read them out with `read_file`.

## Key API

```python
from opensandbox.models.filesystem import WriteEntry

await sandbox.files.write_files([WriteEntry(path="/workspace/analyze.py", data=Path("analyze.py").read_text())])
execution = await sandbox.commands.run("python3 /workspace/analyze.py")
content = await sandbox.files.read_file("/workspace/report.txt")
```

## Try it

Open `02-files/analyze.py` and change the analysis logic — add a word length histogram, or count punctuation. Re-run `make run-02` and the updated output appears in `downloaded_report.txt`.
