terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
  }
  required_version = ">= 1.3"
}

provider "libvirt" {
  uri = var.libvirt_uri
}
