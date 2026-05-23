# Evidence — resource-pressure

**Date:** ____   **Operator:** ____   **TRACE version / commit:** ____
**Agent resource limits during test:** cpu ____ / mem ____
**Run context:** standalone [ ] / during offload herd (N=____) [ ]

## Results (from results/pressure.csv)

| type | breaking point | during (cpu/mem/net) | recovery_s | saturation alert fired? | verify_fails Δ (must be 0) | degraded gracefully? |
|------|----------------|----------------------|-----------|-------------------------|----------------------------|----------------------|
| CPU  |  |  |  |  | 0 |  |
| RAM  |  |  |  |  | 0 |  |
| Disk I/O |  |  |  |  | 0 |  |
| Network |  |  |  |  | 0 |  |
| Conns/FD |  |  |  |  | 0 |  |

## Design questions answered

- **CPU:** did SHA-256 verification become the bottleneck? latency vs CPU: ____
- **RAM:** buffer or stream? OOM behaviour & recovery: ____
- **Disk:** cache back-pressure behaviour: ____
- **Network:** peer-fabric ceiling & fallback path: ____
- **Conns/FD:** exhaustion point & load-shed behaviour: ____

## Invariants

- [ ] Saturation SLI alert fired before hard failure.
- [ ] Degradation was smooth (no cliff), or defect logged: ____
- [ ] Recovery automatic, no manual repair.
- [ ] **Integrity held: 0 chunk-verify failures across all types.**

## Bottleneck summary (capacity ceilings)

CPU: ____  RAM: ____  Disk: ____  Network: ____  Conns: ____

## Notes / defects

____

## Sign-off

QC reviewer: ____   Status: Pass / Fail / Deferred
