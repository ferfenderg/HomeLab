# ADR-0004 — Terraform / Argo CD ownership boundary

**Status:** Accepted
**Date:** 2026-05-22
**Roles:** Platform Engineer, DevOps Engineer, SRE

## Context

Both Terraform and Argo CD can create and reconcile Kubernetes resources. If both manage the same objects, they fight: Terraform plans show drift that Argo introduced, Argo reports out-of-sync because Terraform changed something, and a `terraform destroy` can race Argo's reconciliation. This is a common failure mode and a standard platform-engineering interview question.

## Decision

A clear day-0 / day-2 split:

- **Terraform owns day-0 bootstrap** — things that must exist before GitOps can run: installing Argo CD itself, the root app-of-apps, pre-GitOps platform addons (CNI, cert-manager CRDs where ordering matters), the bootstrap namespaces and RBAC, GitHub repo/org controls, and any cloud/provider resources (Phase 8).
- **Argo CD owns day-2 delivery** — all applications and platform components thereafter, declared in Git via the app-of-apps pattern.

Terraform does not manage individual Argo `Application` workloads; Argo does not manage what Terraform bootstraps. Each component is assigned to exactly one owner, recorded in a small ownership table in `terraform/README.md`.

## Consequences

- Terraform runs rarely (bootstrap and upgrades); Argo runs continuously. State stays small and recovery is predictable.
- No two controllers contend for the same object.
- Cost: a one-time "bootstrap vs delivery" judgment per component. When in doubt, if it's needed to *make GitOps work*, it's Terraform; otherwise it's Argo.
- Terraform state lives **outside** the managed cluster (external MinIO/cloud bucket) to avoid a circular recovery dependency — see Decision Log.
