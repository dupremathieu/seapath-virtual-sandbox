TERRAFORM_DIR := terraform
INVENTORY     := inventory/seapath-sandbox.yaml

# Path to a local clone of https://github.com/seapath/ansible.git
# Default: sibling directory (../ansible). Override with ANSIBLE_REPO=<path>.
ANSIBLE_REPO  ?= ../ansible
PLAYBOOKS      = $(ANSIBLE_REPO)/playbooks

# Extra ansible-playbook flags (e.g. ANSIBLE_OPTS="--check -v")
ANSIBLE_OPTS ?=

.PHONY: all init plan apply destroy \
        ssh-node1 ssh-node2 ssh-node3 \
        console-node1 console-node2 console-node3 \
        ansible-ping ansible-setup \
        ansible-setup-network ansible-setup-ceph ansible-setup-ha \
        help

all: help

## Terraform lifecycle
init:
	cd $(TERRAFORM_DIR) && terraform init

plan:
	cd $(TERRAFORM_DIR) && terraform plan

apply:
	cd $(TERRAFORM_DIR) && terraform apply

destroy:
	cd $(TERRAFORM_DIR) && terraform destroy

## Node access
ssh-node1:
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ansible@192.168.100.101

ssh-node2:
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ansible@192.168.100.102

ssh-node3:
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ansible@192.168.100.103

console-node1:
	virsh console seapath-node1

console-node2:
	virsh console seapath-node2

console-node3:
	virsh console seapath-node3

## Ansible
ansible-ping:
	ansible all -i $(INVENTORY) -m ping $(ANSIBLE_OPTS)

ansible-setup:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/seapath_setup_main.yaml $(ANSIBLE_OPTS)

ansible-setup-network:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/seapath_setup_network.yaml $(ANSIBLE_OPTS)

ansible-setup-ceph:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/cluster_setup_ceph.yaml $(ANSIBLE_OPTS)

ansible-setup-ha:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/cluster_setup_ha.yaml $(ANSIBLE_OPTS)

help:
	@echo "SEAPATH Virtual Sandbox"
	@echo ""
	@echo "Terraform:"
	@echo "  make init              Initialise Terraform (run once)"
	@echo "  make plan              Show planned changes"
	@echo "  make apply             Create/update VMs and networks"
	@echo "  make destroy           Tear down all VMs and networks"
	@echo ""
	@echo "Node access:"
	@echo "  make ssh-node{1,2,3}      SSH into a node"
	@echo "  make console-node{1,2,3}  Open virsh serial console"
	@echo ""
	@echo "Ansible:"
	@echo "  make ansible-ping          Test connectivity to all nodes"
	@echo "  make ansible-setup         Run full SEAPATH setup"
	@echo "  make ansible-setup-network Configure network only"
	@echo "  make ansible-setup-ceph    Deploy Ceph only"
	@echo "  make ansible-setup-ha      Configure HA (Pacemaker/Corosync) only"
	@echo ""
	@echo "Pass extra flags via ANSIBLE_OPTS, e.g.:"
	@echo "  make ansible-setup ANSIBLE_OPTS='-v --check'"
