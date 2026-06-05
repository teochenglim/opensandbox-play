"""06-k8s: Pool pre-warms pods; dispatch tasks into each one via kubectl exec."""
import json
import subprocess
import sys
import time


POOL_LABEL = "sandbox.opensandbox.io/pool-name=tutorial-pool"

# One task per pod shard — same idea as BatchSandbox shardTaskPatches
SHARD_TASKS = [
    (
        "shard-0: word frequency",
        "python3 -c \""
        "import collections; words = 'the quick brown fox jumps over the lazy dog the fox'.split();"
        " freq = collections.Counter(words);"
        " print('\\n'.join(f'{w}: {c}' for w, c in freq.most_common(3)))"
        "\"",
    ),
    (
        "shard-1: system info",
        "python3 -c \""
        "import socket, platform, os;"
        " print(f'host={socket.gethostname()}');"
        " print(f'python={platform.python_version()}');"
        " print(f'cpus={os.cpu_count()}')"
        "\"",
    ),
    (
        "shard-2: hash digest",
        "python3 -c \""
        "import hashlib;"
        " words = ['sandbox', 'opensandbox', 'brownbag', 'agent', 'isolated'];"
        " [print(f'{w}: {hashlib.md5(w.encode()).hexdigest()[:8]}') for w in words]"
        "\"",
    ),
]


def get_pool_pods() -> list[str]:
    result = subprocess.run(
        ["kubectl", "get", "pods", "-l", POOL_LABEL, "-o", "json"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"ERROR: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    items = json.loads(result.stdout).get("items", [])
    return [
        p["metadata"]["name"]
        for p in items
        if p.get("status", {}).get("phase") == "Running"
    ]


def exec_in_pod(pod: str, command: str) -> str:
    result = subprocess.run(
        ["kubectl", "exec", pod, "--", "sh", "-c", command],
        capture_output=True, text=True, timeout=15,
    )
    return result.stdout.strip() if result.returncode == 0 else f"ERROR: {result.stderr.strip()}"


def main() -> None:
    print("==> Getting pool pods...")
    pods = get_pool_pods()
    if not pods:
        print("No running pool pods found. Run 'make run-06' first.")
        sys.exit(1)

    print(f"    {len(pods)} warm pod(s) available: {', '.join(pods)}\n")

    t0 = time.monotonic()
    for i, (label, cmd) in enumerate(SHARD_TASKS):
        pod = pods[i % len(pods)]
        print(f"--- {label}  [{pod}] ---")
        output = exec_in_pod(pod, cmd)
        for line in output.splitlines():
            print(f"    {line}")
        print()

    elapsed = time.monotonic() - t0
    print(f"All {len(SHARD_TASKS)} tasks completed in {elapsed:.1f}s")
    print("(Pool pods were pre-warmed — no cold-start wait)")


if __name__ == "__main__":
    main()
