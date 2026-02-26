locals {
  # OVS RSTP ring topology wiring:
  #   seapath-cluster-12: node1 NIC2 (team0_0) ↔ node2 NIC3 (team0_1)
  #   seapath-cluster-23: node2 NIC2 (team0_0) ↔ node3 NIC3 (team0_1)
  #   seapath-cluster-31: node3 NIC2 (team0_0) ↔ node1 NIC3 (team0_1)
  #
  # ring_a[i] = NIC2 (team0_0) network for node i+1
  ring_a = [
    libvirt_network.ring_12.id, # node1 NIC2
    libvirt_network.ring_23.id, # node2 NIC2
    libvirt_network.ring_31.id, # node3 NIC2
  ]
  # ring_b[i] = NIC3 (team0_1) network for node i+1
  ring_b = [
    libvirt_network.ring_31.id, # node1 NIC3
    libvirt_network.ring_12.id, # node2 NIC3
    libvirt_network.ring_23.id, # node3 NIC3
  ]
}

resource "libvirt_domain" "node" {
  count  = 3
  name   = "seapath-node${count.index + 1}"
  memory = var.node_memory_mib
  vcpu   = var.node_vcpu

  # NIC1: admin (NAT) — fixed MAC for DHCP reservation
  network_interface {
    network_id     = libvirt_network.admin.id
    mac            = var.node_macs[count.index]
    wait_for_lease = true
  }

  # NIC2: team0_0 — ring segment A
  network_interface {
    network_id = local.ring_a[count.index]
  }

  # NIC3: team0_1 — ring segment B
  network_interface {
    network_id = local.ring_b[count.index]
  }

  # OS disk (CoW clone of base image)
  disk {
    volume_id = libvirt_volume.os_disk[count.index].id
  }

  # OSD disk → always /dev/vdb in the guest
  disk {
    volume_id = libvirt_volume.osd_disk[count.index].id
  }

  # XSLT injects fixed PCI slot addresses so the guest OS sees predictable names:
  #   slot 0x03 → NIC1 admin  (enp3s0 / eth0)
  #   slot 0x04 → NIC2 team0_0 (enp4s0 / eth1)
  #   slot 0x05 → NIC3 team0_1 (enp5s0 / eth2)
  xml {
    xslt = file("${path.module}/xslt/domain-pci.xsl")
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
