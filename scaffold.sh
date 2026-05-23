#!/usr/bin/env bash
# scaffold.sh — create the repo skeleton (Phase 0). Idempotent; safe to re-run.
set -euo pipefail
dirs=(
  docs/architecture/adr docs/architecture/diagrams docs/sre docs/security
  docs/iac docs/storage docs/ai-delivery-controls docs/phase-1
  lima ansible/roles
  terraform/modules/cluster-addons terraform/modules/observability terraform/modules/security
  terraform/envs/lab terraform/envs/aws-stub
  k8s/base k8s/overlays/dev k8s/overlays/prod
  apps/argocd trace ci/.github/workflows .github/workflows
  runbooks scenarios evidence
)
for d in "${dirs[@]}"; do mkdir -p "$d"; [ -z "$(ls -A "$d" 2>/dev/null)" ] && touch "$d/.gitkeep"; done

# top-level README stub if missing
[ -f README.md ] || cat > README.md <<'EOF'
# TRACE Platform Lab

A 5-node Apple Silicon Kubernetes/Terraform platform-engineering lab that runs and
operates TRACE (a distributed read-cache for large immutable artifacts) with full
SRE, security, GitOps and resilience treatment.

See `docs/architecture/` for decisions and `docs/phase-1/README.md` to start.
EOF
echo "Scaffold complete."
