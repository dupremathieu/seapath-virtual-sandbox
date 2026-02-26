# Admin network: NAT with DHCP MAC reservations for predictable IPs
resource "libvirt_network" "admin" {
  name      = "seapath-sandbox-admin"
  mode      = "nat"
  addresses = [var.admin_network_cidr]
  dhcp { enabled = true }
  xml {
    xslt = templatefile("${path.module}/xslt/admin-network.xsl.tftpl", {
      nodes = [for i, mac in var.node_macs : {
        mac  = mac
        ip   = var.node_admin_ips[i]
        name = "node${i + 1}"
      }]
    })
  }
}

# Isolated L2 ring segments — no DHCP, no IP addressing
# Ring: node1 ↔ node2
resource "libvirt_network" "ring_12" {
  name = "seapath-cluster-12"
  mode = "none"
}

# Ring: node2 ↔ node3
resource "libvirt_network" "ring_23" {
  name = "seapath-cluster-23"
  mode = "none"
}

# Ring: node3 ↔ node1
resource "libvirt_network" "ring_31" {
  name = "seapath-cluster-31"
  mode = "none"
}
