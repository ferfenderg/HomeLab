#!/usr/bin/env bash
# run-offload-study.sh — one A/B run: launch N consumers of the same artifact,
# time the fleet, and pull origin/peer/offload metrics from Prometheus.
#
#   ./run-offload-study.sh <baseline|treatment> <N> <size>
#
# Output: appends a row to results/offload-<runid>.csv and per-pod durations.
set -euo pipefail

MODE="${1:?baseline|treatment}"; N="${2:?fan-out}"; SIZE="${3:-2Gi}"
NS="${TRACE_NS:-trace}"
PROM_URL="${PROM_URL:-http://localhost:9090}"
CONTROLLER="${TRACE_CONTROLLER_URL:?set TRACE_CONTROLLER_URL}"
ADMIN_KEY="${TRACE_ADMIN_API_KEY:?set TRACE_ADMIN_API_KEY}"
AGENT_URL="${TRACE_AGENT_URL:?node-local agent base URL}"
RUN_ID="${MODE}-n${N}-$(date +%s)"
mkdir -p results

promq() { # promq '<expr>' -> scalar value
  curl -fsS --get "$PROM_URL/api/v1/query" --data-urlencode "query=$1" \
    | jq -r '.data.result[0].value[1] // "0"'
}

echo "== run $RUN_ID (mode=$MODE N=$N size=$SIZE) =="

# 1. Ensure the artifact exists at the requested size.  ADJUST to TRACE's register API.
ARTIFACT_ID="${ARTIFACT_ID:-perf-$SIZE}"
curl -fsS -X POST "$CONTROLLER/v1/artifacts" \
  -H "Authorization: Bearer $ADMIN_KEY" -H 'Content-Type: application/json' \
  -d "{\"id\":\"$ARTIFACT_ID\",\"size\":\"$SIZE\"}" >/dev/null || true

# 2. Set the single independent variable: peer fetch on/off.
#    ADJUST to your serve-control / policy override (force origin vs allow peer).
if [ "$MODE" = "baseline" ]; then FORCE_ORIGIN=true; else FORCE_ORIGIN=false; fi
curl -fsS -X PUT "$CONTROLLER/v1/policy/serve" \
  -H "Authorization: Bearer $ADMIN_KEY" -H 'Content-Type: application/json' \
  -d "{\"artifact\":\"$ARTIFACT_ID\",\"force_origin\":$FORCE_ORIGIN}" >/dev/null

# 3. Cold cache: clear agent caches so each run starts equal. ADJUST/remove for warm runs.
kubectl -n "$NS" rollout restart ds/trace-agent >/dev/null && kubectl -n "$NS" rollout status ds/trace-agent

# 4. Launch N consumers simultaneously (thundering herd).
START=$(date +%s)
for i in $(seq 1 "$N"); do
  INDEX=$i RUN_ID=$RUN_ID ARTIFACT_ID=$ARTIFACT_ID AGENT_URL=$AGENT_URL \
    envsubst < consumer-job.yaml | kubectl apply -f - >/dev/null
done
kubectl -n "$NS" wait --for=condition=complete --timeout=1800s job -l "run=$RUN_ID"
END=$(date +%s); WINDOW=$(( END - START + 5 ))

# 5. Per-pod fetch durations (p50/p95) from logs.
kubectl -n "$NS" logs -l "run=$RUN_ID" --tail=-1 | grep FETCH_RESULT \
  | sed -E 's/.*dur=([0-9.]+)s/\1/' | sort -n > "results/dur-$RUN_ID.txt"
P95=$(awk '{a[NR]=$1} END{print a[int(NR*0.95)+ (NR<1?0:0)]}' "results/dur-$RUN_ID.txt")

# 6. Pull origin/peer/offload metrics for the run window.  ADJUST metric names.
ORIGIN_BYTES=$(promq "increase(trace_origin_bytes_total[${WINDOW}s])")
PEER_BYTES=$(promq   "increase(trace_peer_bytes_total[${WINDOW}s])")
ORIGIN_CONNS=$(promq "max_over_time(minio_s3_requests_inflight_total[${WINDOW}s])")
VERIFY_FAILS=$(promq "increase(trace_chunk_verify_failures_total[${WINDOW}s])")
OFFLOAD=$(echo "scale=4; $PEER_BYTES / ($PEER_BYTES + $ORIGIN_BYTES + 0.0001)" | bc)

# 7. Record.
CSV="results/offload.csv"
[ -f "$CSV" ] || echo "run_id,mode,N,size,fleet_seconds,p95_seconds,origin_bytes,peer_bytes,offload_ratio,origin_conns,verify_fails" > "$CSV"
echo "$RUN_ID,$MODE,$N,$SIZE,$((END-START)),$P95,$ORIGIN_BYTES,$PEER_BYTES,$OFFLOAD,$ORIGIN_CONNS,$VERIFY_FAILS" | tee -a "$CSV"

# 8. Cleanup this run's jobs.
kubectl -n "$NS" delete job -l "run=$RUN_ID" >/dev/null
