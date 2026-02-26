# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Project Overview

SEAPATH Virtual Sandbox provisions a 3-node SEAPATH cluster on QEMU/KVM for local development and testing. It uses Terraform (dmacvicar/libvirt provider) to create the VMs and networks, and relies on the [SEAPATH Ansible repo](https://github.com/seapath/ansible.git) for cluster configuration.

## Repository Structure

```
.
├── Makefile                      # Convenience targets for Terraform and Ansible
├── README.md
├── terraform.tfvars.example      # Copy to terraform/terraform.tfvars and edit
├── terraform/
│   ├── providers.tf              # Terraform + dmacvicar/libvirt ~0.8
│   ├── variables.tf              # All input variables with defaults
│   ├── networks.tf               # Admin NAT network + 3 isolated ring segments
│   ├── volumes.tf                # Base image, 3 CoW OS disks, 3 OSD disks
│   ├── nodes.tf                  # 3 VM domains with NIC wiring and PCI slot XSLT
│   ├── outputs.tf                # IPs, SSH commands, console commands
│   └── xslt/
│       ├── admin-network.xsl.tftpl   # Injects DHCP MAC reservations into libvirt XML
│       └── domain-pci.xsl            # Fixes NIC PCI slots for predictable iface names
└── inventory/
    ├── seapath-sandbox.yaml      # Ansible inventory (3-node cluster)
    └── group_vars/
        └── all.yml               # StrictHostKeyChecking=no for sandbox VMs
```

## External Dependency: SEAPATH Ansible Repo

This sandbox does **not** contain Ansible playbooks or roles. It expects the [seapath/ansible](https://github.com/seapath/ansible.git) repo to be cloned as a sibling directory (`../ansible`). The `ANSIBLE_REPO` Makefile variable can override this path.

## Key Design Decisions

### Network topology
- **Admin network**: libvirt NAT (`192.168.100.0/24`). DHCP reservations are injected via XSLT because the dmacvicar/libvirt provider does not support `<host>` entries natively.
- **Cluster ring**: 3 isolated L2 segments (`mode = "none"`) wiring the nodes in an OVS RSTP ring. No DHCP, no IP addressing at the libvirt level — Ansible assigns cluster IPs statically.

### Predictable guest interface names
An XSLT transform (`xslt/domain-pci.xsl`) injects fixed PCI slot addresses onto the NICs so the guest OS always sees `enp3s0`/`enp4s0`/`enp5s0` (Debian/CentOS/OL) or `eth0`/`eth1`/`eth2` (Yocto), regardless of libvirt's default ordering. Slot assignments: `0x03` = admin, `0x04` = team0\_0, `0x05` = team0\_1.

### Inventory differences from a physical cluster
- `ceph_osd_disk: "/dev/vdb"` — virtio disk, no PCI path needed
- `osd memory target: 4294967296` — 4 GiB (halved from the 8 GiB production default)
- `isolcpus: ""` — no CPU isolation in VMs
- `ptp_interface` omitted — no PTP hardware available
- `ansible_ssh_extra_args` disables strict host key checking (host keys change on `terraform destroy`)

## Common Tasks

**Provision VMs:**
```bash
cp terraform.tfvars.example terraform/terraform.tfvars
# edit terraform/terraform.tfvars — set base_image_path
make init && make apply
```

**Run Ansible phases:**
```bash
make ansible-ping            # connectivity check
make ansible-setup-network   # calls seapath_setup_network.yaml
make ansible-setup-ceph      # calls cluster_setup_ceph.yaml
make ansible-setup-ha        # calls cluster_setup_ha.yaml
make ansible-setup           # full setup via seapath_setup_main.yaml
```

**Destroy everything:**
```bash
make destroy
```

## Linting / Validation

Terraform files can be validated with:
```bash
cd terraform && terraform fmt -check && terraform validate
```

Ansible inventory can be checked with (from the ansible repo):
```bash
ansible-lint -c ansible-lint.conf ../seapath-virtual-sandbox/inventory/seapath-sandbox.yaml
```
