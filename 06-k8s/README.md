# 06-k8s — Pool + BatchSandbox

Creates a `Pool` of pre-warmed K8s pods, then dispatches three tasks — one per pod — via `kubectl exec`. Requires `kubectl` and `helm`.

```bash
make run-06
```

## What you'll see

```
==> Creating Pool (warm standby sandboxes)...
==> Waiting for pool pods to be Ready...
pod/tutorial-pool-abc condition met
pod/tutorial-pool-def condition met
pod/tutorial-pool-ghi condition met

NAME            TOTAL   ALLOCATED   AVAILABLE
tutorial-pool   3       0           3

==> Dispatching BatchSandbox (3 replicas from pool)...

==> Running tasks in pool pods...
    3 warm pod(s) available: tutorial-pool-abc, ...

--- shard-0: word frequency  [tutorial-pool-abc] ---
    the: 3
    fox: 2
    quick: 1

--- shard-1: system info  [tutorial-pool-def] ---
    host=tutorial-pool-def
    python=3.12.x
    cpus=8

--- shard-2: hash digest  [tutorial-pool-ghi] ---
    sandbox: 93bc63e0
    opensandbox: dee127c2
    ...

All 3 tasks completed in 0.4s
```

The pool pods were already running before you dispatched the tasks — that's the point. No cold-start wait regardless of how many replicas you ask for.

## What Pool and BatchSandbox do

**Pool** keeps N warm pods running at all times. When demand arrives, pods are allocated instantly — no image pull, no container start latency.

**BatchSandbox** declares how many replicas you want and which pool to pull from. The controller allocates pods from the pool and optionally runs a different task in each replica via `shardTaskPatches`.

## Cleanup

```bash
make clean-06
```

## If it's slow or pods don't come up

Check available resources: `kubectl describe nodes`. The pool requests 250m CPU + 256Mi RAM per pod. Scale `bufferMin` down in `sandbox-pool.yaml` if the node is constrained.
