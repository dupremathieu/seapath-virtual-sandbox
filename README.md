# SEAPATH Virtual Sandbox

A fully virtual 3-node SEAPATH cluster running on QEMU/KVM, for local development and testing without physical hardware.

## Prerequisites

- `libvirt` / `qemu-kvm` installed and running (`systemctl status libvirtd`)
- `terraform` >= 1.3 with the [dmacvicar/libvirt provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest)
- `virsh` CLI (usually part of `libvirt-client`)
- `ansible` 2.16 — installed by `prepare.sh` in the SEAPATH Ansible repo (see Quick Start)
- A SEAPATH qcow2 image with an `ansible` user whose `~/.ssh/authorized_keys` contains your public key

## Quick Start

```bash
# 1. Clone this repo and the SEAPATH Ansible repo as siblings
git clone https://github.com/dupremathieu/seapath-virtual-sandbox.git
git clone https://github.com/seapath/ansible.git

# 2. Install Ansible dependencies from the Ansible repo
cd ansible
./prepare.sh
cd ../seapath-virtual-sandbox

# 3. Copy and edit the Terraform variable file
cp terraform.tfvars.example terraform/terraform.tfvars
$EDITOR terraform/terraform.tfvars   # Set base_image_path at minimum

# 4. Initialise Terraform and create the VMs
make init
make apply

# 5. Verify SSH connectivity
make ansible-ping

# 6. Run the full SEAPATH setup
make ansible-setup
```

The Makefile expects the SEAPATH Ansible repo at `../ansible` by default. Override with:
```bash
make ansible-setup ANSIBLE_REPO=/path/to/ansible
```

## Network Design

### Admin network (`seapath-sandbox-admin`)
- Mode: NAT, CIDR `192.168.100.0/24`
- DHCP reservations via XSLT injection (MAC → IP):

| Node  | MAC               | IP              |
|-------|-------------------|-----------------|
| node1 | `52:54:00:aa:bb:01` | `192.168.100.101` |
| node2 | `52:54:00:aa:bb:02` | `192.168.100.102` |
| node3 | `52:54:00:aa:bb:03` | `192.168.100.103` |

### Cluster ring (OVS RSTP)
Three isolated L2 segments wire the nodes in a ring:

| Network              | Node A side            | Node B side            |
|----------------------|------------------------|------------------------|
| `seapath-cluster-12` | node1 NIC2 (`team0_0`) | node2 NIC3 (`team0_1`) |
| `seapath-cluster-23` | node2 NIC2 (`team0_0`) | node3 NIC3 (`team0_1`) |
| `seapath-cluster-31` | node3 NIC2 (`team0_0`) | node1 NIC3 (`team0_1`) |

Cluster IPs (assigned statically by Ansible): node1=`192.168.55.1`, node2=`192.168.55.2`, node3=`192.168.55.3`.

### Guest interface names
Fixed PCI slot addresses are injected via XSLT so the guest OS sees predictable names:

| Slot   | NIC  | Debian/CentOS/OL | Yocto |
|--------|------|------------------|-------|
| `0x03` | NIC1 admin    | `enp3s0` | `eth0` |
| `0x04` | NIC2 team0\_0 | `enp4s0` | `eth1` |
| `0x05` | NIC3 team0\_1 | `enp5s0` | `eth2` |

## Yocto Images

Set these variables in `terraform/terraform.tfvars`:

```hcl
iface_admin     = "eth0"
iface_cluster_a = "eth1"
iface_cluster_b = "eth2"
```

Also update `network_interface`, `team0_0`, and `team0_1` in `inventory/seapath-sandbox.yaml`.

## Available Make Targets

| Target | Description |
|--------|-------------|
| `init` | Initialise Terraform (run once) |
| `plan` | Show planned changes |
| `apply` | Create/update VMs and networks |
| `destroy` | Tear down everything |
| `ssh-node{1,2,3}` | SSH into a node |
| `console-node{1,2,3}` | Open virsh serial console |
| `ansible-ping` | Test SSH connectivity |
| `ansible-setup` | Full SEAPATH setup |
| `ansible-setup-network` | Network configuration only |
| `ansible-setup-ceph` | Ceph deployment only |
| `ansible-setup-ha` | HA (Pacemaker/Corosync) only |

Pass extra Ansible flags with `ANSIBLE_OPTS`:
```bash
make ansible-setup ANSIBLE_OPTS="-v --check"
```

## Verification

1. `make init` — Terraform initialises without errors
2. `make apply` — 3 VMs created, 4 networks visible in `virsh net-list`
3. `make ansible-ping` — All 3 nodes respond
4. `make ansible-setup-network` — OVS bridge `team0` visible on each node
5. `virsh console seapath-node1` — Ring interfaces (`enp4s0`, `enp5s0`) are up

## Known Limitations

**PCI slot conflicts**: If libvirt already places a device at slot `0x03`–`0x05`, the XSLT will fail or produce duplicate addresses. Bump the slots to `0x06/0x07/0x08` in `xslt/domain-pci.xsl` and update the `iface_*` variables and the inventory accordingly.

**Image prerequisites**: The qcow2 image must have an `ansible` user with your SSH public key pre-loaded. This is the responsibility of the SEAPATH image build, not this sandbox.

**Ceph deployment path**: The inventory is compatible with both ceph-ansible and cephadm. The actual path is auto-detected by the `detect_seapath_distro` role based on the OS in the image.

**No PTP**: `ptp_interface` is intentionally omitted — there is no PTP hardware in a virtual sandbox.

**Resource usage**: Each node uses 4 GiB RAM and 4 vCPUs by default, plus 20 GiB for the Ceph OSD disk. A full 3-node cluster requires at least 12 GiB free RAM on the host.
