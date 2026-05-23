#!/usr/bin/env bash
# verify-layout.sh — confirm the repo has the expected files in the expected places.
# Run from the repo root:  bash scripts/verify-layout.sh
set -u
expected=(
  README.md LICENSE Makefile scaffold.sh
  lima/k3s-node.yaml
  docs/phase-1/README.md
  docs/architecture/adr/0004-terraform-argocd-ownership-boundary.md
  docs/architecture/adr/0005-k3s-bootstrap-networking-guardrails.md
  scenarios/perf-offload/README.md
  scenarios/perf-offload/run-offload-study.sh
  scenarios/perf-offload/throttle-origin.sh
  scenarios/perf-offload/consumer-job.yaml
  scenarios/perf-offload/queries.promql
  scenarios/perf-offload/evidence-template.md
  scenarios/resource-pressure/README.md
  scenarios/resource-pressure/stressors.yaml
  scenarios/resource-pressure/run-pressure-matrix.sh
  scenarios/resource-pressure/evidence-template.md
  scripts/verify-layout.sh
)
misplaced=(
  0004-terraform-argocd-ownership-boundary.md
  0005-k3s-bootstrap-networking-guardrails.md
)
fail=0
echo "== expected files =="
for f in "${expected[@]}"; do
  if [ -f "$f" ]; then echo "  OK    $f"; else echo "  MISS  $f"; fail=1; fi
done
echo "== should NOT be at repo root =="
for f in "${misplaced[@]}"; do
  if [ -f "$f" ]; then echo "  STRAY $f  -> move to docs/architecture/adr/"; fail=1
  else echo "  ok    (absent) $f"; fi
done
echo
if [ "$fail" -eq 0 ]; then echo "LAYOUT OK"; else echo "LAYOUT INCOMPLETE"; fi
exit "$fail"
