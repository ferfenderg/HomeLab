#!/usr/bin/env bash
# run-pressure-matrix.sh — inject each resource stressor, capture before/during/after
# metrics and recovery time. Optional arg runs a single type (cpu|mem|disk|net).
set -euo pipefail

NS="${TRACE_NS:-trace}"
PROM_URL="${PROM_URL:-http://localhost:9090}"
ONLY="${1:-all}"
mkdir -p results

promq() { curl -fsS --get "$PROM_URL/api/v1/query" --data-urlencode "query=$1" \
            | jq -r '.data.result[0].value[1] // "0"'; }

verify_fails() { promq 'increase(trace_chunk_verify_failures_total[6m])'; }
agent_ready()  { kubectl -n "$NS" get pods -l app=trace-agent \
                   -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' \
                 | grep -qv false; }

declare -A CHAOS=( [cpu]=trace-cpu-max [mem]=trace-mem-max [disk]=trace-disk-latency [net]=trace-peer-bandwidth )
declare -A KIND=(  [cpu]=stresschaos   [mem]=stresschaos  [disk]=iochaos            [net]=networkchaos )

run_one() {
  local t="$1" name="${CHAOS[$1]}" kind="${KIND[$1]}"
  echo "== pressure: $t ($name) =="
  local vf0; vf0=$(verify_fails)

  kubectl apply -f stressors.yaml >/dev/null
  # keep only the one we want active
  for k in "${!CHAOS[@]}"; do [ "$k" != "$t" ] && kubectl -n "$NS" delete "${KIND[$k]}" "${CHAOS[$k]}" >/dev/null 2>&1 || true; done

  sleep 60   # let it bite; capture "during"
  local cpu mem net; \
  cpu=$(promq 'max(sum by (pod)(rate(container_cpu_usage_seconds_total{namespace="trace",pod=~"trace-agent.*"}[1m])))'); \
  mem=$(promq 'max(container_memory_working_set_bytes{namespace="trace",pod=~"trace-agent.*"})'); \
  net=$(promq 'max(sum by (instance)(rate(node_network_transmit_bytes_total{device!~"lo|cilium.*"}[1m])))')
  echo "  during: cpu=$cpu mem=$mem net=$net"

  kubectl -n "$NS" delete "$kind" "$name" >/dev/null 2>&1 || true

  # recovery: time until all agents ready again
  local r0 r1; r0=$(date +%s)
  for _ in $(seq 1 120); do agent_ready && break; sleep 2; done
  r1=$(date +%s)
  local vf1; vf1=$(verify_fails)

  local CSV="results/pressure.csv"
  [ -f "$CSV" ] || echo "type,during_cpu,during_mem,during_net,recovery_s,verify_fail_delta" > "$CSV"
  echo "$t,$cpu,$mem,$net,$((r1-r0)),$(echo "$vf1 - $vf0" | bc)" | tee -a "$CSV"
  echo "  recovered in $((r1-r0))s; verify_fail_delta=$(echo "$vf1 - $vf0" | bc) (MUST be 0)"
}

if [ "$ONLY" = "all" ]; then for t in cpu mem disk net; do run_one "$t"; done
else run_one "$ONLY"; fi
