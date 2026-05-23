#!/usr/bin/env bash
# throttle-origin.sh — make the MinIO origin a measured bottleneck.
#
# Primary method: Cilium egress bandwidth manager via pod annotation
#   (requires Cilium installed with bandwidthManager.enabled=true).
# Fallback method: tc tbf/netem inside the origin pod (needs NET_ADMIN).
#
# Usage:
#   ./throttle-origin.sh apply 100M     # cap origin egress to 100 Mbit/s
#   ./throttle-origin.sh clear
set -euo pipefail

NS="${TRACE_ORIGIN_NS:-trace}"
SELECTOR="${TRACE_ORIGIN_SELECTOR:-app=minio}"   # ADJUST to your origin pod label
ACTION="${1:?apply|clear}"
LIMIT="${2:-100M}"

case "$ACTION" in
  apply)
    echo "Annotating origin ($SELECTOR) with egress limit $LIMIT (Cilium bandwidth manager)…"
    # Cilium reads kubernetes.io/egress-bandwidth at pod creation, so patch the
    # controller template and roll the pod.
    kubectl -n "$NS" patch deploy minio --type merge -p \
      "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"kubernetes.io/egress-bandwidth\":\"$LIMIT\"}}}}}"
    kubectl -n "$NS" rollout status deploy/minio
    echo "Applied. Verify with: cilium bandwidth list  (on a node)"
    ;;
  clear)
    echo "Removing egress limit…"
    kubectl -n "$NS" patch deploy minio --type=json -p \
      '[{"op":"remove","path":"/spec/template/metadata/annotations/kubernetes.io~1egress-bandwidth"}]' || true
    kubectl -n "$NS" rollout status deploy/minio
    echo "Cleared."
    ;;
  *) echo "unknown action: $ACTION"; exit 2;;
esac

# ---- tc fallback (uncomment if not using Cilium bandwidth manager) ----
# POD=$(kubectl -n "$NS" get pod -l "$SELECTOR" -o jsonpath='{.items[0].metadata.name}')
# apply:  kubectl -n "$NS" exec "$POD" -- tc qdisc add dev eth0 root tbf rate "$LIMIT" burst 32kbit latency 400ms
# clear:  kubectl -n "$NS" exec "$POD" -- tc qdisc del dev eth0 root
