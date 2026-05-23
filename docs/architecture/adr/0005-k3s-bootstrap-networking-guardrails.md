# ADR-0005 — k3s bootstrap networking guardrails

**Status:** Accepted
**Date:** 2026-05-22
**Roles:** Platform Engineer, Infrastructure Security Engineer, SRE

## Context

k3s ships several networking components enabled by default: flannel (CNI), an embedded NetworkPolicy controller, Traefik (ingress), and ServiceLB/klipper (LoadBalancer). The lab targets Cilium (eBPF) as CNI, ingress-nginx as ingress, and MetalLB as the bare-metal LoadBalancer. The CNI is an **install-time** decision: retrofitting Cilium onto a running flannel cluster is a disruptive migration, not a runtime swap. Leaving Traefik or ServiceLB enabled alongside ingress-nginx/MetalLB causes two controllers to contend for ports 80/443 and for `LoadBalancer` services.

## Decision

- The **long-lived cluster (Phase 2)** is initialised with these flags, and Cilium is installed as the first action before any workload:
  ```
  --flannel-backend=none \
  --disable-network-policy \
  --disable=traefik \
  --disable=servicelb
  # add --disable-kube-proxy only if using Cilium kube-proxy replacement
  ```
- ingress-nginx and MetalLB are installed after Cilium, replacing the disabled Traefik/ServiceLB.
- The **Phase 1 single-node MVP is explicitly disposable** and may run default flannel (it only disables Traefik/ServiceLB to keep habits consistent). When the long-lived cluster is built, it is **rebuilt, not migrated**.

## Consequences

- A clean eBPF dataplane from day one: Hubble flow visibility, NetworkPolicy enforcement and L7 policy available immediately; no mid-life CNI migration.
- No ingress/LoadBalancer controller contention.
- Cost: bring-up uses explicit flags rather than defaults, and Phase 1 is throwaway by design. Both are acceptable and documented.
