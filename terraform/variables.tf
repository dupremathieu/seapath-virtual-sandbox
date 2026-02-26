variable "base_image_path" {
  description = "Path to the SEAPATH qcow2 base image (must have 'ansible' user with SSH key pre-authorized)"
  type        = string
}

variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "libvirt_pool" {
  description = "Libvirt storage pool name"
  type        = string
  default     = "default"
}

variable "node_memory_mib" {
  description = "RAM per node in MiB"
  type        = number
  default     = 4096
}

variable "node_vcpu" {
  description = "Number of vCPUs per node"
  type        = number
  default     = 4
}

variable "osd_disk_size_bytes" {
  description = "Ceph OSD disk size in bytes"
  type        = number
  default     = 21474836480 # 20 GiB
}

variable "admin_network_cidr" {
  description = "Admin network CIDR"
  type        = string
  default     = "192.168.100.0/24"
}

variable "node_admin_ips" {
  description = "Admin IPs for each node (must match DHCP MAC reservations)"
  type        = list(string)
  default     = ["192.168.100.101", "192.168.100.102", "192.168.100.103"]
}

variable "node_cluster_ips" {
  description = "Cluster network IPs for each node (assigned statically by Ansible)"
  type        = list(string)
  default     = ["192.168.55.1", "192.168.55.2", "192.168.55.3"]
}

variable "node_macs" {
  description = "MAC addresses for admin NICs (used for DHCP reservations)"
  type        = list(string)
  default     = ["52:54:00:aa:bb:01", "52:54:00:aa:bb:02", "52:54:00:aa:bb:03"]
}

variable "iface_admin" {
  description = "Guest OS admin interface name (use 'eth0' for Yocto)"
  type        = string
  default     = "enp3s0"
}

variable "iface_cluster_a" {
  description = "Guest OS team0_0 interface name (use 'eth1' for Yocto)"
  type        = string
  default     = "enp4s0"
}

variable "iface_cluster_b" {
  description = "Guest OS team0_1 interface name (use 'eth2' for Yocto)"
  type        = string
  default     = "enp5s0"
}
