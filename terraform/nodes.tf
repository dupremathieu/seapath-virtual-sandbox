locals {
  # OVS RSTP ring topology wiring:
  #   seapath-cluster-12: node1 NIC2 (team0_0) ↔ node2 NIC3 (team0_1)
  #   seapath-cluster-23: node2 NIC2 (team0_0) ↔ node3 NIC3 (team0_1)
  #   seapath-cluster-31: node3 NIC2 (team0_0) ↔ node1 NIC3 (team0_1)
  #
  # ring_a[i] = NIC2 (team0_0) network for node i+1
  ring_a = [
    libvirt_network.ring_12.name, # node1 NIC2
    libvirt_network.ring_23.name, # node2 NIC2
    libvirt_network.ring_31.name, # node3 NIC2
  ]
  # ring_b[i] = NIC3 (team0_1) network for node i+1
  ring_b = [
    libvirt_network.ring_31.name, # node1 NIC3
    libvirt_network.ring_12.name, # node2 NIC3
    libvirt_network.ring_23.name, # node3 NIC3
  ]
}

resource "libvirt_domain" "node" {
  count       = 3
  name        = "seapath-node${count.index + 1}"
  type        = "kvm"
  memory      = var.node_memory_gib
  memory_unit = "GiB"
  vcpu        = var.node_vcpu

  cpu = {
    mode = "host-passthrough"
  }

  features = {
    acpi = true
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    firmware     = "efi"
    firmware_info = {
      features = [
        { name = "enrolled-keys", enabled = "no" },
        { name = "secure-boot", enabled = "no" },
      ]
    }
  }

  devices = {
    # NIC1: admin (NAT) — fixed MAC for DHCP reservation
    # NIC2: team0_0 — ring segment A
    # NIC3: team0_1 — ring segment B
    #
    # Interface ordering determines PCI slot assignment:
    #   slot 0x03 → NIC1 admin   (enp0s3)
    #   slot 0x04 → NIC2 team0_0 (enp0s4)
    #   slot 0x05 → NIC3 team0_1 (enp0s5)
    interfaces = [
      {
        source = {
          network = {
            network = libvirt_network.admin.name
          }
        }
        mac = {
          address = var.node_macs[count.index]
        }
        model       = { type = "virtio" }
        wait_for_ip = {}
      },
      {
        source = {
          network = {
            network = local.ring_a[count.index]
          }
        }
        model = { type = "virtio" }
        # Match guest OVS team0 MTU; libvirt can't set mtu on bridge-mode
        # networks, so it must be declared per-interface on the domain.
        mtu = { size = 9000 }
      },
      {
        source = {
          network = {
            network = local.ring_b[count.index]
          }
        }
        model = { type = "virtio" }
        mtu   = { size = 9000 }
      },
    ]

    # OS disk (CoW clone of base image)
    # OSD disk → always /dev/vdb in the guest
    disks = [
      {
        driver = { name = "qemu", type = "qcow2" }
        source = {
          file = {
            file = libvirt_volume.os_disk[count.index].path
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        driver = { name = "qemu", type = "qcow2" }
        source = {
          file = {
            file = libvirt_volume.osd_disk[count.index].path
          }
        }
        target = {
          dev = "vdb"
          bus = "virtio"
        }
      },
    ]

    consoles = [
      {
        target = {
          type = "serial"
          port = 0
        }
      },
    ]

    graphics = [
      {
        vnc = {
          auto_port = true
        }
      },
    ]
  }
}
