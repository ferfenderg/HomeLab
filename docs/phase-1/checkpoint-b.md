# Phase 1 · Checkpoint B — MinIO origin

Deploy the artifact origin, create a bucket, and upload one synthetic immutable artifact.

## Steps

```bash
# 1. Namespace
kubectl apply -f k8s/base/minio/00-namespace.yaml

# 2. Credentials Secret — NOT committed (random password, good hygiene)
kubectl -n trace create secret generic minio-creds \
  --from-literal=rootUser=minioadmin \
  --from-literal=rootPassword="$(openssl rand -base64 18)"

# 3. MinIO
kubectl apply -f k8s/base/minio/minio.yaml
kubectl -n trace rollout status deploy/minio

# 4. Create bucket + upload the test artifact
kubectl apply -f k8s/base/minio/minio-setup-job.yaml
kubectl -n trace wait --for=condition=complete --timeout=300s job/minio-setup
kubectl -n trace logs job/minio-setup
```

## Exit check

- [ ] `kubectl -n trace get pods` shows `minio` Running and `minio-setup` Completed.
- [ ] The setup-job log shows `test-artifact.bin` listed in `local/artifacts/` and a recorded SHA-256.
- [ ] Save that log to `evidence/phase-1/checkpoint-b.txt`:
      `kubectl -n trace logs job/minio-setup > evidence/phase-1/checkpoint-b.txt`
- [ ] Commit.

## Optional — view the console

```bash
kubectl -n trace port-forward svc/minio 9001:9001
# browse http://localhost:9001
# username: minioadmin
# password: kubectl -n trace get secret minio-creds -o jsonpath='{.data.rootPassword}' | base64 -d ; echo
```

## Notes

- This is the origin TRACE fetches from at Checkpoint C, and later the constrained bottleneck in the perf-offload scenario.
- `:latest` images are fine for the disposable Phase 1 cluster; pin `RELEASE.*` / versioned tags when you build the long-lived cluster.
- The `minio-creds` Secret is created imperatively so plaintext credentials never enter git — the same discipline that becomes SOPS/age + External Secrets later.
