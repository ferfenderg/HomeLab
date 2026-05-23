# Scenario: perf-offload — origin read-I/O offload & scaling study

**Family:** performance / capacity (Phase 7)
**Roles proven:** SRE, Platform Engineer, Cloud Infrastructure Engineer
**Related SLIs:** origin-offload ratio, peer-fetch ratio, p95 fetch latency, corrupt-chunk acceptance (= 0)

## Objective

Prove TRACE's core thesis — that it shifts repeated read I/O *off the origin storage and onto the peer network* — and characterise how that benefit scales with fleet size. This is a scalability/offload study, **not** a raw throughput benchmark; the transferable result is the *shape of the curve*, not lab MB/s.

## Hypothesis (falsifiable)

Under a bandwidth-constrained origin, as the number of concurrent consumers `N` of the same artifact grows:

- **H1 (offload):** origin bytes served stays ~flat (≈ one artifact) while peer-served bytes grow; offload ratio → `(N-1)/N`.
- **H2 (origin protection):** origin concurrent connections stay ~constant (≈1) regardless of `N`.
- **H3 (scaling):** aggregate time-to-serve-the-fleet scales *sublinearly* with `N`, versus the origin-only baseline which scales ~linearly once the origin saturates.
- **H4 (integrity under load):** chunk-verification failures remain 0 throughout.

If any of H1–H4 fails, the result is still publishable — a negative result with a clear bottleneck is honest evidence.

## Experimental design

Single independent variable: **peer fetch on/off**, flipped on the *same* binary.

| Run | Peer fetch | Models |
|-----|-----------|--------|
| **baseline** | disabled (force origin) | status quo — the fleet thunders the storage server |
| **treatment** | enabled | TRACE — one origin fetch, rest distributed peer-to-peer |

Controlled variables: identical artifact, identical constrained origin, identical `N`, wired GbE (see Limitations). Dependent variables: the metrics below.

The origin is made a **deliberate, measured bottleneck** — this is not cheating, it reproduces the exact scenario TRACE targets (a saturated storage server), just at a scale you can instrument. See `throttle-origin.sh`.

## Load patterns

1. **Thundering herd:** all `N` consumers request the same artifact at t=0 (a training fleet starting at once).
2. **N-sweep:** N = 1,2,3,4,5 … then beyond 5 by running multiple consumer Jobs per node (logical fan-out exceeds physical nodes).
3. **Size sweep:** small vs large multi-chunk artifacts (peer fetch should help more as size grows).
4. **Cold vs warm:** first run (one origin fetch) vs warm run (origin load → ~0).
5. **Herd-during-chaos:** run the herd while killing a peer mid-distribution (cross-links to `../resource-pressure/` and your node-loss scenario).

## Metrics & queries

See `queries.promql`. Capture per run: origin bytes served, origin in-flight connections, origin egress rate, peer-served bytes, **offload ratio**, per-node fetch latency p50/p95/p99, aggregate fleet completion time, chunk-verify failures (must be 0), agent CPU/NIC saturation.

## The headline chart

One chart sells this: **x-axis = N (concurrent consumers), two lines = origin egress bytes** (or aggregate completion time) for baseline vs treatment. Baseline climbs ~linearly as the fleet starves the origin; treatment stays flat because origin work is ≈ one fetch regardless of N. Plot offload ratio on a second axis.

## How to run

```bash
# 0. Prereqs: cluster up, TRACE deployed, MinIO origin, Prometheus reachable.
kubectl -n monitoring port-forward svc/prometheus 9090:9090 &   # or set PROM_URL

# 1. Constrain the origin (Cilium egress bandwidth; tc fallback inside the script)
./throttle-origin.sh apply 100M

# 2. Run the A/B across the N-sweep (writes results/offload-<runid>.csv)
for N in 1 2 3 4 5 8 10; do
  ./run-offload-study.sh baseline  "$N" 2Gi
  ./run-offload-study.sh treatment "$N" 2Gi
done

# 3. Remove the constraint
./throttle-origin.sh clear
```

Then fill in `evidence-template.md` and attach the headline chart.

## Exit criteria

- [ ] Baseline and treatment runs completed across the full N-sweep with results CSV.
- [ ] H1 confirmed: offload ratio rises toward `(N-1)/N`; origin bytes ~flat in treatment.
- [ ] H2 confirmed: origin in-flight connections bounded in treatment.
- [ ] H3 confirmed: treatment fleet-completion scales sublinearly vs baseline.
- [ ] H4 confirmed: 0 chunk-verify failures in every run.
- [ ] Headline chart produced; the network-saturation point (the *moved* bottleneck) identified and stated.
- [ ] Limitations + extrapolation model written.

## Honest limitations & extrapolation

- Absolute throughput is **lab-bound**: laptop NICs, virtio overhead, a small switch, and MinIO-on-a-MacBook are not a datacentre fabric or a storage array. Report **ratios and curves**, not MB/s.
- TRACE **moves** the bottleneck from storage to network. The study must find where the peer fabric saturates and state it as the new ceiling — that is a feature of the analysis, not a flaw.
- Extrapolation model to state alongside the data: at measured offload ratio `R`, a fleet of `N` pulling an `S`-sized artifact reduces origin egress from ~`N·S` to ~`S`, an `(1 − 1/N)` reduction. Present lab data as *validation of this model*, then state the production implication.
- Optional scale validation (Phase 8): one short, budget-capped cloud burst (20–50 spot nodes) to confirm the curve holds at higher `N`, then tear down.

## Wiring to TRACE (adjust before first run)

The scripts use placeholders — map these to TRACE's real surface:

| Placeholder | Map to |
|-------------|--------|
| register artifact | TRACE controller registration endpoint |
| force-origin / peer-fetch toggle | your serve-control / policy override (the serve override path) |
| agent fetch URL | the node-local agent artifact-fetch endpoint |
| metric names (`trace_origin_bytes_total`, `trace_peer_bytes_total`, `trace_fetch_duration_seconds`, `trace_chunk_verify_failures_total`) | TRACE's actual exported metric names |
