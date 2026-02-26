output "node_admin_ips" {
  description = "Admin IP addresses of the nodes"
  value = {
    for i in range(3) : "node${i + 1}" => var.node_admin_ips[i]
  }
}

output "ssh_commands" {
  description = "SSH commands to access each node"
  value = {
    for i in range(3) : "node${i + 1}" => "ssh ansible@${var.node_admin_ips[i]}"
  }
}

output "console_commands" {
  description = "virsh console commands to access each node"
  value = {
    for i in range(3) : "node${i + 1}" => "virsh console seapath-node${i + 1}"
  }
}

output "virsh_networks" {
  description = "Libvirt networks created by this workspace"
  value       = ["seapath-sandbox-admin", "seapath-cluster-12", "seapath-cluster-23", "seapath-cluster-31"]
}
