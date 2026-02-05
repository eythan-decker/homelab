# Proxmox Full-Clone
# ---

module "ella_class_vms" {
  source = "./modules/proxmox_vms"

  vm_class_name     = "pve-ella"
  vm_template_name  = "ubuntu-server-noble"
  proxmox_node_name = "pve01"

  class_defaults = {
    cpu_cores = 4
    memory    = 4096
    disks = {
      virtio0 = { size = "32G", storage = "local-lvm" }
      virtio1 = { size = "64G", storage = "pve01-zfs" }
    }
  }

  vms = {
    "101" = { description = "Ella Class VM. k3s master1" }
    "102" = { description = "Ella Class VM. k3s master2" }
    "103" = { description = "Ella Class VM. k3s master3" }
    "104" = {
      description = "Ella Class VM. Critical K3s worker node non HA."
      disks = {
        virtio0 = { size = "232G", storage = "local-lvm" }
        virtio2 = { size = "1200G", storage = "k8s-dir-storage", iothread = true }
      }
    }
  }

  vm_serveradmin_password = var.serveradmin_password
}

module "elliot_class_vms" {
  source = "./modules/proxmox_vms"

  vm_class_name     = "pve-elliot"
  vm_template_name  = "ubuntu-server-noble"
  proxmox_node_name = "pve01"

  class_defaults = {
    cpu_cores = 6
    memory    = 16384
    disks = {
      virtio0 = { size = "32G", storage = "local-lvm" }
      virtio1 = { size = "64G", storage = "pve01-zfs" }
    }
  }

  vms = {
    "120" = {
      description = "Elliot Class VM. k3s agent1"
      disks = {
        virtio0 = { size = "232G", storage = "local-lvm" }
      }
      usb = { device_id = "1a86:55d4", usb3 = false }
    }
  }

  vm_serveradmin_password = var.serveradmin_password
}
