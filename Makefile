.PHONY: help start stop serve verify setup run-all clean run-01 run-02 run-03 run-04 run-05 run-06 clean-06

help:
	@echo "OpenSandbox Tutorial"
	@echo ""
	@echo "Quick start:"
	@echo "  make start       install deps, start server in background, verify"
	@echo "  make stop        stop background server"
	@echo ""
	@echo "Dev:"
	@echo "  make serve       start server in foreground (Ctrl+C to stop)"
	@echo "  make verify      re-run prerequisite checks"
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
OSB_IMAGE      ?= opensandbox/server:latest
OSB_CONTAINER  ?= opensandbox-server
export DOCKER_HOST := $(or $(DOCKER_HOST),unix://$(HOME)/.colima/default/docker.sock)

# opensandbox-server itself runs as a Docker container (not a host `uv run`
# process) so it shares the same Docker daemon as the sandboxes it creates.
# `sandbox.toml` sets [docker].host_ip so sandbox/egress endpoints are
# reachable from the host. --network host is required here: the server also
# uses host_ip for its *own* internal readiness probe against sidecar
# containers (e.g. egress), which only resolves correctly if the server
# shares the same network namespace as those sibling containers' published
# ports (see 00-setup/sandbox.docker.toml for details).
# _run-container is the one place that shells out to `docker run`; ARGS picks
# background (-d) vs. foreground+auto-remove (--rm).
ARGS ?= -d

_run-container:
	@docker rm -f $(OSB_CONTAINER) >/dev/null 2>&1 || true
	docker run $(ARGS) --name $(OSB_CONTAINER) \
	  --network host \
	  -v /var/run/docker.sock:/var/run/docker.sock \
	  -v $(CURDIR)/sandbox.toml:/etc/opensandbox/config.toml:ro \
	  -e SANDBOX_CONFIG_PATH=/etc/opensandbox/config.toml \
	  -e OPENSANDBOX_INSECURE_SERVER=YES \
	  $(OSB_IMAGE)

start: setup
	@echo "==> Starting OpenSandbox server (Docker container) in background..."
	@$(MAKE) --no-print-directory _run-container ARGS=-d >/dev/null
	@sleep 2 && curl -sf $(OSB_SERVER_URL)/health >/dev/null \
	  && echo "Server up (container=$(OSB_CONTAINER)). Logs: docker logs -f $(OSB_CONTAINER)" \
	  || echo "Server may still be starting — check: docker logs -f $(OSB_CONTAINER)"
	@$(MAKE) --no-print-directory verify

stop:
	@docker rm -f $(OSB_CONTAINER) >/dev/null 2>&1 && echo "Server stopped." || echo "No server running."
	@$(MAKE) --no-print-directory clean-06

serve:
	@echo "==> Starting OpenSandbox server (Docker container, foreground) on $(OSB_SERVER_URL)..."
	$(MAKE) --no-print-directory _run-container ARGS=--rm

setup:
	@echo "==> Installing dependencies..."
	uv sync
	@echo "==> Generating server config (if not present)..."
	@[ -f sandbox.toml ] || cp 00-setup/sandbox.docker.toml sandbox.toml
	@echo "==> Pulling $(OSB_IMAGE) (if not present)..."
	@docker image inspect $(OSB_IMAGE) >/dev/null 2>&1 || docker pull $(OSB_IMAGE)

verify: setup
	@curl -sf --max-time 2 $(OSB_SERVER_URL)/health >/dev/null 2>&1 || { \
	  echo "==> Server not running, starting in background..."; \
	  $(MAKE) --no-print-directory _run-container ARGS=-d >/dev/null; \
	  sleep 2; \
	}
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
	@command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found, skipping K8s cleanup."; exit 0; }
	@kubectl delete batchsandbox word-count --ignore-not-found 2>/dev/null || true
	@kubectl delete pool tutorial-pool --ignore-not-found 2>/dev/null || true
	@if command -v helm >/dev/null 2>&1 && helm status opensandbox-controller -n opensandbox-system >/dev/null 2>&1; then \
	  helm uninstall opensandbox-controller -n opensandbox-system >/dev/null 2>&1; \
	  for i in $$(seq 1 15); do \
	    helm status opensandbox-controller -n opensandbox-system >/dev/null 2>&1 || break; \
	    sleep 1; \
	  done; \
	fi
	@sleep 3
	@command -v docker >/dev/null 2>&1 && { \
	  leftover=$$(docker ps -aq --filter "name=tutorial-pool" --filter "name=opensandbox-controller"); \
	  [ -n "$$leftover" ] && docker rm -f $$leftover >/dev/null 2>&1 && echo "Removed orphaned sandbox/controller containers." || true; \
	} || true
	@echo "K8s exercise resources cleaned up."

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
