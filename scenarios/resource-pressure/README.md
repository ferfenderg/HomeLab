# Scenario: resource-pressure — saturation, bottleneck discovery & graceful degradation

**Family:** resilience / capacity (Phase 7)
**Roles proven:** SRE, Platform Engineer, Cloud Infrastructure Engineer, Infrastructure Security Engineer
**Related:** saturation SLI, error-budget burn-rate alert; cross-links to `../perf-offload/` and node-loss

## Objective

Drive each resource to saturation on the TRACE agents and controller — CPU, memory, disk I/O, network, and connection/file-descriptor limits — to (a) **find where TRACE breaks** (the bottleneck/capacity ceiling) and (b) confirm it **degrades gracefully and recovers** without data loss or silent corruption. Run each pressure type both standalone and *during* the perf-offload herd, because the interesting failures appear under combined load.

## Why this matters for TRACE specifically

TRACE has resource-sensitive hot paths, and each pressure type probes a real design question:

- **CPU** → SHA-256 chunk verification is CPU-bound. Under CPU starvation, does verification become the throughput bottleneck? Does fetch latency climb but integrity hold (verify failures stay 0)?
- **Memory** → does the agent **buffer whole artifacts** in memory (OOM risk on large artifacts) or **stream chunks**? Memory pressure reveals which. On OOMKill, does the agent restart and re-serve from cache, and do peers/controller recover without manual repair?
- **Disk I/O** → cache writes/evictions. Under I/O pressure does write latency back-pressure fetches correctly, or does the cache corrupt/stall?
- **Network** → the *moved* bottleneck from the offload study. Where does the peer fabric saturate, and does TRACE fall back to origin or another peer cleanly?
- **Connections / FDs** → high concurrent peer connections. Does the agent exhaust file descriptors or its connection pool, and does it shed load gracefully?

## Method

Two levers, used together:

1. **Injected stress** via Chaos Mesh (`stressors.yaml`): `StressChaos` (CPU/memory), `IOChaos` (disk latency), `NetworkChaos` (bandwidth/latency). Chaos Mesh uses stress-ng under the hood.
2. **Constrained limits**: set low `resources.limits` on the agent and run the offload herd — this finds throttle/OOM behaviour with no external tooling and is the most reproducible form.

For each pressure type, capture **before → during → after**: does the saturation SLI alert fire? what is the breaking point (intensity at which fetches fail)? what is the recovery time once pressure is removed? did integrity hold (verify failures = 0)?

## Pressure matrix

| Type | Tool | Breaking-point question | Must-hold invariant |
|------|------|-------------------------|---------------------|
| CPU max | StressChaos cpu | latency vs CPU; verification starvation | verify failures = 0 |
| RAM max | StressChaos memory + low mem limit | buffer vs stream; OOM recovery | recover w/o manual repair |
| Disk I/O | IOChaos latency | cache write back-pressure | no cache corruption |
| Network | NetworkChaos bandwidth | peer-fabric ceiling; fallback | fetch still succeeds (slower) |
| Conns/FD | offload herd × high N + low FD ulimit | FD/pool exhaustion | graceful load-shed, no crash loop |

## How to run

```bash
kubectl -n monitoring port-forward svc/prometheus 9090:9090 &   # for metric capture
./run-pressure-matrix.sh                  # standalone passes
# combined: start the herd, then inject pressure mid-flight
( cd ../perf-offload && ./run-offload-study.sh treatment 10 2Gi ) &
./run-pressure-matrix.sh cpu              # inject one type during the herd
```

## Expected results

- Saturation SLI alert fires before hard failure (early-warning works).
- Latency degrades smoothly toward the breaking point rather than cliff-failing.
- On OOMKill / restart: agent recovers, re-serves from cache, peers/controller reconcile automatically.
- **Integrity invariant holds in every case: chunk-verify failures = 0** (degradation must never mean serving unverified data).
- Each bottleneck has a documented ceiling number.

## Exit criteria

- [ ] All five pressure types run standalone and at least one run during the offload herd.
- [ ] Breaking point recorded for each type.
- [ ] Recovery time recorded for CPU/RAM/disk after pressure removal.
- [ ] Saturation alert observed firing.
- [ ] Integrity invariant (0 verify failures) held throughout — or a defect logged if not.
- [ ] `evidence-template.md` completed.

## Safety

- Memory and I/O fills are **bounded** (Chaos Mesh `size`/`duration`, size-capped volumes — never root-disk fills; see the disk-pressure note in the Failure Testing sheet).
- Scope chaos with `selector` to the `trace` namespace only. Never select platform/system namespaces.
