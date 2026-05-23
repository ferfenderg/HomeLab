VM ?= trace-lab
KUBECONFIG_FILE := $(CURDIR)/.kube/config
export KUBECONFIG := $(KUBECONFIG_FILE)

.PHONY: up kubeconfig status demo down
## up: start the single-node k3s VM and wire kubeconfig
up:
	limactl start --name=$(VM) lima/k3s-node.yaml --tty=false
	$(MAKE) kubeconfig
	kubectl get nodes -o wide

## kubeconfig: pull k3s.yaml from the VM to ./.kube/config (server already 127.0.0.1:6443)
kubeconfig:
	mkdir -p .kube
	limactl shell $(VM) sudo cat /etc/rancher/k3s/k3s.yaml > $(KUBECONFIG_FILE)
	@echo "export KUBECONFIG=$(KUBECONFIG_FILE)"

## status: show VM + cluster state
status:
	limactl list
	kubectl get nodes,pods -A

## demo: full Phase 1 vertical slice (added in the next increment: MinIO + TRACE + fetch/verify + 1 panel)
demo:
	@echo "Checkpoint A only so far. Next increment wires MinIO -> TRACE -> fetch/verify -> Grafana panel."
	@echo "See docs/phase-1/README.md."

## down: stop and delete the VM
down:
	-limactl stop $(VM)
	-limactl delete $(VM)
