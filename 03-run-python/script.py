import sys, hashlib, json, random

words = ["sandbox", "isolated", "brownbag", "opensandbox", "agent"]
random.shuffle(words)

results = []
for w in words:
    h = hashlib.md5(w.encode()).hexdigest()[:8]
    results.append({"word": w, "hash": h, "len": len(w)})

print(json.dumps(results, indent=2))
print(f"\nPython {sys.version.split()[0]} — running inside the sandbox!")
