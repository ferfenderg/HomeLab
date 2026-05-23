# Phase 1 — single-node MVP (vertical slice)

**Goal:** the simplest thing that works end-to-end — one Lima VM, single-node k3s, MinIO origin, TRACE controller + one agent, one artifact fetched and SHA-256-verified, one metric on one Grafana panel, all behind `make demo`.

**Disposable:** per ADR-0005 this cluster is throwaway; Phase 2 rebuilds it with Cilium. Don't invest in ingress/MetalLB/Cilium here.

---

## Checkpoints

### ▶ Checkpoint A — cluster up (THIS INCREMENT)

```bash
# prereqs (once)
brew install lima kubectl

# bring up single-node k3s
./scaffold.sh          # creates the repo skeleton (Phase 0)
make up                # starts the VM, installs k3s, wires kubeconfig
make status
```

**Exit check:**
- [ ] `kubectl get nodes` shows one node `Ready`.
- [ ] `kubectl get pods -A` shows coredns + metrics-server running (no traefik / svclb pods — confirms the disable flags worked).
- [ ] `git commit` the repo skeleton + this passing state.

**Evidence:** `kubectl get nodes -o wide` and `kubectl get pods -A` output → `evidence/phase-1/checkpoint-a.txt`.

### ⏳ Checkpoint B — MinIO origin (next increment)
Deploy MinIO, create a bucket, upload one synthetic large artifact. Exit: artifact listed via `mc`/console.

### ⏳ Checkpoint C — TRACE deploy + fetch/verify (next increment)
Containerise TRACE for arm64 (`docker buildx`), push to ghcr.io, deploy controller (Deployment) + Postgres (StatefulSet) + one agent. Register the artifact, fetch it through the agent, and capture a SHA-256 verification success in the agent logs. Exit: one verified fetch; `trace_chunk_verify_failures_total == 0`.

### ⏳ Checkpoint D — one metric, one panel (next increment)
Minimal Prometheus + Grafana; scrape one TRACE metric (e.g. cache hits or bytes served); build one panel. Exit: panel shows live data.

### ⏳ Checkpoint E — `make demo` + record (next increment)
Wire A–D into `make demo`; record with asciinema. This is the Phase 1 exit evidence.

---

## Phase 1 exit criteria
- [ ] `make demo` brings the slice up from scratch on a clean machine.
- [ ] A fresh observer sees one artifact served and SHA-256-verified.
- [ ] One live Grafana panel.
- [ ] Recording + outputs in `evidence/phase-1/`.
- [ ] `governance`/`docs/ai-delivery-controls/contract-lock.md` opened for the TRACE↔platform interface (image tags, ports, env, `TRACE_ADMIN_API_KEY`).

## You are here
**Checkpoint A.** Clear it, commit, then I'll generate the B–E manifests (MinIO, TRACE deploy, Prometheus) as the next increment — that step needs your real TRACE image and its register/fetch API.
