.PHONY: help setup serve serve-bg stop verify run-all clean run-01 run-02 run-03 run-04 run-05 run-06

help:
	@echo "OpenSandbox Tutorial"
	@echo ""
	@echo "Setup:"
	@echo "  make setup       install deps + generate sandbox.toml"
	@echo ""
	@echo "Server:"
	@echo "  make serve       start server in foreground (Ctrl+C to stop)"
	@echo "  make serve-bg    start server in background"
	@echo "  make stop        stop background server"
	@echo "  make verify      check all prerequisites"
	@echo ""
	@echo "Exercises:"
	@echo "  make run-01      01-basics     — create sandbox, run commands, stream output"
	@echo "  make run-02      02-files      — write files into sandbox, run, read results"
	@echo "  make run-03      03-run-python — execute Python code in isolation"
	@echo "  make run-04      04-egress     — network allow/deny policies"
	@echo "  make run-05      05-mcp        — Claude Code MCP integration (see README)"
	@echo "  make run-06      06-k8s        — Pool + BatchSandbox (requires K8s)"
	@echo "  make run-all     run 01–06 in sequence"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean       remove __pycache__ and downloaded files"
	@echo "  make clean-06    delete K8s Pool + BatchSandbox resources"

OSB_SERVER_URL ?= http://localhost:8080
OSB_DOMAIN     ?= localhost:8080
DOCKER_HOST    := $(or $(DOCKER_HOST),unix://$(HOME)/.colima/default/docker.sock)

setup:
	@echo "==> Installing dependencies..."
	uv sync
	@echo "==> Generating server config (if not present)..."
	@[ -f sandbox.toml ] || uv run opensandbox-server init-config sandbox.toml --example docker
	@echo ""
	@echo "Setup complete. Run 'make serve-bg' then 'make run-01'."

serve:
	@echo "==> Starting OpenSandbox server on $(OSB_SERVER_URL)..."
	DOCKER_HOST=$(DOCKER_HOST) OPENSANDBOX_INSECURE_SERVER=YES uv run opensandbox-server --config sandbox.toml

serve-bg:
	@echo "==> Starting OpenSandbox server in background..."
	DOCKER_HOST=$(DOCKER_HOST) OPENSANDBOX_INSECURE_SERVER=YES uv run opensandbox-server --config sandbox.toml &>/tmp/osb-server.log & echo $$! > .server.pid
	@sleep 2 && curl -sf $(OSB_SERVER_URL)/health >/dev/null && echo "Server up (PID=$$(cat .server.pid)). Logs: tail -f /tmp/osb-server.log" || echo "Server may still be starting — check: tail -f /tmp/osb-server.log"

stop:
	@[ -f .server.pid ] && kill $$(cat .server.pid) && rm .server.pid && echo "Server stopped." || echo "No .server.pid found."

verify:
	OSB_SERVER_URL=$(OSB_SERVER_URL) bash 00-setup/verify.sh

run-01:
	SANDBOX_DOMAIN=$(OSB_DOMAIN) uv run python 01-basics/main.py

run-02:
	SANDBOX_DOMAIN=$(OSB_DOMAIN) uv run python 02-files/main.py

run-03:
	SANDBOX_DOMAIN=$(OSB_DOMAIN) uv run python 03-run-python/main.py

run-04:
	SANDBOX_DOMAIN=$(OSB_DOMAIN) uv run python 04-egress/main.py

run-05:
	SANDBOX_DOMAIN=$(OSB_DOMAIN) uv run python 05-mcp/main.py

run-06:
	@echo "==> Checking K8s controller..."
	@helm status opensandbox-controller -n opensandbox-system &>/dev/null 2>&1 || \
	  (echo "Installing controller..." && \
	   helm install opensandbox-controller \
	     https://github.com/alibaba/OpenSandbox/releases/download/helm/opensandbox-controller/0.1.0/opensandbox-controller-0.1.0.tgz \
	     --namespace opensandbox-system --create-namespace && \
	   kubectl rollout status deployment -n opensandbox-system --timeout=120s)
	@echo "==> Creating Pool (warm standby sandboxes)..."
	kubectl apply -f 06-k8s/sandbox-pool.yaml
	@echo "==> Waiting for pool pods to be Ready (up to 60s)..."
	@sleep 5
	kubectl wait pod -l sandbox.opensandbox.io/pool-name=tutorial-pool \
	  --for=condition=Ready --timeout=60s
	@echo ""
	@echo "==> Pool status (warm pods ready to allocate):"
	@kubectl get pool tutorial-pool
	@echo ""
	@kubectl get pods -l sandbox.opensandbox.io/pool-name=tutorial-pool
	@echo ""
	@echo "==> Dispatching BatchSandbox (3 replicas from pool)..."
	kubectl apply -f 06-k8s/batch-sandbox.yaml
	@sleep 3
	@echo ""
	@echo "==> BatchSandbox status:"
	@kubectl get batchsandbox word-count
	@echo ""
	@echo "==> Running tasks in pool pods..."
	uv run python 06-k8s/main.py
	@echo ""
	@echo "    Pool pre-warmed pods — no cold-start wait. Run 'make clean-06' to tear down."

clean-06:
	kubectl delete batchsandbox word-count --ignore-not-found
	kubectl delete pool tutorial-pool --ignore-not-found

run-all:
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  01-basics     — create sandbox, run commands, stream"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	make run-01
	@sleep 2
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  02-files      — write files into sandbox, run, read"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	make run-02
	@sleep 2
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  03-run-python — copy local script into sandbox, execute"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	make run-03
	@sleep 2
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  04-egress     — network allow/deny policies"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	make run-04
	@sleep 2
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  05-mcp        — drive opensandbox via MCP tools"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	make run-05
	@sleep 2
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  06-k8s        — Pool + BatchSandbox (requires K8s)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	make run-06
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  All exercises complete."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

clean:
	@echo "==> Cleaning up..."
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -delete 2>/dev/null || true
	find . -name "downloaded_*" -delete 2>/dev/null || true
	@echo "Done."
