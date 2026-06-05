# 04-egress — Network Allow / Deny Policies

Creates a sandbox with a network policy: two domains allowed, everything else blocked. Then probes four URLs to verify the policy works.

```bash
make run-04
```

## What you'll see

```
[sandbox] created: <id>  (egress: allowlist)
Probing egress rules...
  https://api.github.com/zen               → 200 OK     (allowed) ✓
  https://pypi.org/simple/requests/        → 200 OK     (allowed) ✓
  https://httpbin.org/get                  → blocked    (denied)  ✓
  https://example.com                      → blocked    (denied)  ✓
[sandbox] killed: <id>
```

Policy is set at creation time — you can't change it after the sandbox starts.

## Key API

```python
from opensandbox.models.sandboxes import NetworkPolicy, NetworkRule

policy = NetworkPolicy(
    defaultAction="deny",
    egress=[
        NetworkRule(action="allow", target="api.github.com"),
        NetworkRule(action="allow", target="pypi.org"),
    ],
)
sandbox = await Sandbox.create("python:3.12", connection_config=config,
                                timeout=timedelta(minutes=10), network_policy=policy)
```

## Try it

Add `NetworkRule(action="allow", target="httpbin.org")` to the policy and re-run. The third probe should flip from blocked to 200 OK.
