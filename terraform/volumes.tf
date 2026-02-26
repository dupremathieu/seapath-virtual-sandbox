# Base image — uploaded once, shared as CoW backing store
resource "libvirt_volume" "base_image" {
  name   = "seapath-sandbox-base"
  pool   = var.libvirt_pool
  source = var.base_image_path
  format = "qcow2"
}

# Per-node OS disks — thin CoW clones of the base image
resource "libvirt_volume" "os_disk" {
  count          = 3
  name           = "seapath-sandbox-node${count.index + 1}-os.qcow2"
  pool           = var.libvirt_pool
  base_volume_id = libvirt_volume.base_image.id
  format         = "qcow2"
}

# Per-node Ceph OSD disks — blank raw volumes, always /dev/vdb in the guest
resource "libvirt_volume" "osd_disk" {
  count  = 3
  name   = "seapath-sandbox-node${count.index + 1}-osd.qcow2"
  pool   = var.libvirt_pool
  size   = var.osd_disk_size_bytes
  format = "qcow2"
}
