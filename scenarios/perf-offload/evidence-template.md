# Evidence — perf-offload study

**Date:** ____   **Operator:** ____   **TRACE version / commit:** ____
**Cluster:** 5× Apple Silicon (3 cp + 2 worker)   **Link:** wired GbE [ ] / Wi-Fi [ ]
**Origin constraint:** egress capped to ____ (method: Cilium bandwidth / tc)
**Artifact size(s):** ____

## Results (from results/offload.csv)

| mode | N | size | fleet_s | p95_s | origin_bytes | peer_bytes | offload_ratio | origin_conns | verify_fails |
|------|---|------|---------|-------|--------------|------------|---------------|--------------|--------------|
| baseline  | 1 |  |  |  |  |  |  |  | 0 |
| treatment | 1 |  |  |  |  |  |  |  | 0 |
| baseline  | 5 |  |  |  |  |  |  |  | 0 |
| treatment | 5 |  |  |  |  |  |  |  | 0 |
| …         |   |  |  |  |  |  |  |  |  |

## Headline chart

> Attach: origin egress bytes vs N (baseline vs treatment), offload ratio on 2nd axis.
> `evidence/perf-offload/origin-egress-vs-N.png`

## Hypothesis check

- [ ] **H1 offload** — origin bytes ~flat in treatment; offload ratio → (N-1)/N. Observed: ____
- [ ] **H2 origin protection** — origin in-flight conns bounded in treatment. Observed: ____
- [ ] **H3 scaling** — treatment fleet-time sublinear vs baseline. Observed: ____
- [ ] **H4 integrity** — 0 verify failures all runs. Observed: ____

## The moved bottleneck

Peer fabric saturates at approximately: ____ (N=____, ____ Mbit/s aggregate). This is the new ceiling.

## Extrapolation

Measured offload ratio R = ____ at N = ____. Model: origin egress drops from ~N·S to ~S → (1 − 1/N) reduction. Production implication: ____

## Limitations observed

____

## Sign-off

QC reviewer: ____   Status: Pass / Fail / Deferred
