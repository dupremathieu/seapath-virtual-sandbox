---
name: seapath-virtual-sandbox
description: Provision, boot, and configure the 3-node SEAPATH virtual sandbox (QEMU/KVM via Terraform + Ansible). Use when the user wants to start/stop the cluster, run the SEAPATH Ansible setup, connect to nodes, or run tests against the sandbox. This skill is intended for any AI coding agent (e.g., Claude Code, OpenCode, etc.).
---

# SEAPATH Virtual Sandbox

A 3-node SEAPATH cluster on QEMU/KVM. Terraform (dmacvicar/libvirt) creates the VMs and networks; the external [seapath/ansible](https://github.com/seapath/ansible.git) repo configures the cluster. All commands are wrapped by the `Makefile` at the repo root — prefer `make` targets over invoking `terraform` / `ansible-playbook` directly.

## Repo layout (what matters)

- `Makefile` — entry point for every operation
- `terraform/` — VM and network definitions; `terraform/terraform.tfvars` is gitignored and must be created from `terraform.tfvars.example`
- `inventory/seapath-sandbox.yaml` — Ansible inventory used by every `ansible-*` target
- `inventory/group_vars/all.yml` — sets `StrictHostKeyChecking=no` (host keys change on `terraform destroy`)
- The SEAPATH Ansible repo is **not** in this repo. It is expected at `./ansible` (default) or `../ansible`. Override with `ANSIBLE_REPO=<path>`.

## Environment setup (one-time)

Before anything else, verify host prerequisites and create the tfvars file.

1. Check host services:
   ```bash
   systemctl status libvirtd openvswitch
   ```
   Both must be active. OVS is required because the cluster ring uses RSTP BPDUs that Linux bridges silently drop.

2. Verify passwordless `sudo ovs-vsctl` for the current user (`make apply` / `make destroy` call `sudo ovs-vsctl add-br/del-br`). If missing, add `/etc/sudoers.d/<user>` with:
   ```
   <user> ALL=(root) NOPASSWD: /usr/bin/ovs-vsctl
   ```

3. Clone the SEAPATH Ansible repo as a sibling and run its `prepare.sh`:
   ```bash
   git clone https://github.com/seapath/ansible.git ../ansible
   (cd ../ansible && ./prepare.sh)
   ```
   Then export `ANSIBLE_REPO=../ansible` or pass it on each `make` invocation. Default in this repo's Makefile is `./ansible`.

4. Create the tfvars file (gitignored):
   ```bash
   cp terraform.tfvars.example terraform/terraform.tfvars
   ```
   At minimum, set `base_image_path` to a SEAPATH qcow2 image. The image **must** ship an `ansible` user whose `~/.ssh/authorized_keys` contains the host user's SSH public key — this is a property of the image build, not configurable from the sandbox.

## Bring the cluster up

Run from the repo root:

```bash
make init                         # one-time: terraform init
make apply                        # creates 3 VMs + 4 libvirt networks + 3 OVS bridges
make ansible-ping                 # SSH reachability check (must pass before setup)
make ansible-setup ANSIBLE_REPO=../ansible
```

`make ansible-setup` runs the full pipeline (`seapath_setup_main.yaml`). Individual phases are also available and run in this order if running manually:

```bash
make ansible-setup-network ANSIBLE_REPO=../ansible   # OVS team0 + RSTP ring
make ansible-setup-ceph    ANSIBLE_REPO=../ansible   # cephadm (cluster_setup_cephadm.yaml)
make ansible-setup-ha      ANSIBLE_REPO=../ansible   # Pacemaker/Corosync
```

Pass extra ansible flags via `ANSIBLE_OPTS`, e.g. `ANSIBLE_OPTS="-v"` or `ANSIBLE_OPTS="--check"`.

## Lifecycle

| Goal                          | Command                                           |
|-------------------------------|---------------------------------------------------|
| Start all VMs                 | `make start`                                      |
| Graceful stop                 | `make stop` (falls back to force after timeout)   |
| Tear down everything          | `make destroy`                                    |
| Snapshot all VMs              | `make snapshot SNAPSHOT=<name>` (default `default`) |
| Restore all VMs               | `make restore SNAPSHOT=<name>`                    |
| List / delete snapshots       | `make snapshot-list` / `make snapshot-delete`     |

Take a snapshot named e.g. `post-setup` right after `ansible-setup` succeeds — restoring it is the fastest way to get back to a clean configured cluster between test runs.

`LIBVIRT_URI` defaults to `qemu:///system`. Override only if the user is using session mode.

## Connecting to the nodes for tests

Three ways to reach the nodes — pick the one that matches the workflow:

1. **`make ssh-node{1,2,3}`** — interactive shell as `admin` with `sudo -s`. The Makefile already disables strict host key checking, so this works even after `make destroy && make apply`. Use for ad-hoc inspection.

2. **Direct `ssh`** — for scripted test commands, use the `ansible` user (this is the user the inventory connects as):
   ```bash
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       ansible@192.168.100.101 -- <command>
   ```
   Node IPs: node1=`192.168.100.101`, node2=`192.168.100.102`, node3=`192.168.100.103`.

3. **`ansible` ad-hoc commands** — best for fan-out tests across the whole cluster. Always reference this repo's inventory:
   ```bash
   ansible all          -i inventory/seapath-sandbox.yaml -m ping
   ansible hypervisors  -i inventory/seapath-sandbox.yaml -m shell -a "ovs-vsctl show"
   ansible mons         -i inventory/seapath-sandbox.yaml -m shell -a "ceph -s" -b
   ```
   Add `-b` for root. Use group names from the inventory (`hypervisors`, `cluster_machines`, `mons`, `osds`, `clients`).

4. **`make console-node{1,2,3}`** — virsh serial console. Use only when SSH/networking is broken (e.g. debugging `seapath-setup-network` failures). Exit with `Ctrl-]`.

## Ansible inventory: key facts

File: `inventory/seapath-sandbox.yaml`. Important to know when writing tests or new playbooks:

- **Connection user**: `ansible_user: ansible` (not `admin` — `admin` is only used by `make ssh-node*`).
- **Admin interface**: `network_interface: enp1s0` on every node (q35 pcie-root-port slot, set by Terraform).
- **Cluster ring interfaces** (used by OVS RSTP): `team0_0=enp2s0`, `team0_1=enp3s0`. These are only meaningful inside `cluster_machines`.
- **Cluster IPs** (assigned statically by the network playbook, not by libvirt): node1=`192.168.55.1`, node2=`192.168.55.2`, node3=`192.168.55.3`. Subnet `192.168.55.0/24` is `cluster_network` / `public_network` for Ceph.
- **Ceph OSD disk**: `/dev/vdb` on every node (the second virtio disk created by Terraform).
- **No PTP, no isolcpus, no observers** — these are intentionally empty/omitted in the sandbox.

When a playbook needs only a subset of nodes, use the existing groups (`hypervisors`, `cluster_machines`, `mons`, `osds`, `clients`) rather than adding new ones.

## Verifying a healthy cluster

After `make ansible-setup`:

```bash
# All 3 nodes reachable
make ansible-ping

# OVS ring is up and RSTP converged (one port should be in BLOCKING state)
ansible cluster_machines -i inventory/seapath-sandbox.yaml -b \
    -m shell -a "ovs-vsctl show && ovs-appctl rstp/show team0"

# Ceph health
ansible node1 -i inventory/seapath-sandbox.yaml -b -m shell -a "ceph -s"

# Pacemaker
ansible node1 -i inventory/seapath-sandbox.yaml -b -m shell -a "crm_mon -1"
```

`ceph -s` should report `HEALTH_OK` with 3 mons and 3 OSDs (`up+in`). If Ceph mons fail to elect, the most common cause is a broken cluster ring — check OVS bridges on the host (`sudo ovs-vsctl list-br | grep ovs-ring`) and inside the guests.

## Common pitfalls

- **`make apply` fails on `ovs-vsctl`**: passwordless sudo is missing — see step 2 of environment setup.
- **`ansible-ping` fails**: VM didn't boot, or the qcow2 image lacks the user's SSH key. Use `make console-node1` to confirm boot, then check `~ansible/.ssh/authorized_keys` inside the guest.
- **Host keys changed after recreate**: expected. The inventory disables strict host key checking; `make ssh-node*` does the same. Don't `ssh-keygen -R` — it's not needed.
- **`ANSIBLE_REPO` not set**: the Makefile defaults to `./ansible`. If the SEAPATH ansible repo lives elsewhere (commonly `../ansible`), pass `ANSIBLE_REPO=../ansible` on every `ansible-*` target, or export it in the shell.
- **Out of RAM**: each node uses 4 GiB + 4 vCPUs. Full cluster needs ≥12 GiB free.

## When NOT to use this skill

This skill covers operating the sandbox. It does **not** cover modifying SEAPATH Ansible roles or playbooks — those live in the external `seapath/ansible` repo. For changes to the cluster's actual configuration logic, work in that repo and re-run `make ansible-setup` here to test.
