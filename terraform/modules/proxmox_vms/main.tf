# Creates new VMs based on existing VM template. Can create 1 or multiple VMs.
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

locals {
  # Merge class defaults with per-VM overrides
  vm_configs = {
    for vm_id, vm in var.vms : vm_id => {
      description = vm.description
      cpu_cores   = coalesce(vm.cpu_cores, var.class_defaults.cpu_cores)
      memory      = coalesce(vm.memory, var.class_defaults.memory)

      disks = {
        virtio0 = vm.disks != null && vm.disks.virtio0 != null ? vm.disks.virtio0 : var.class_defaults.disks.virtio0
        virtio1 = vm.disks != null && vm.disks.virtio1 != null ? vm.disks.virtio1 : var.class_defaults.disks.virtio1
        virtio2 = vm.disks != null ? vm.disks.virtio2 : null
      }

      usb = vm.usb
    }
  }
}

resource "proxmox_vm_qemu" "pve_vm" {
  for_each = var.vms

  # VM General Settings
  target_node = var.proxmox_node_name
  vmid        = each.key
  name        = "${var.vm_class_name}-${each.key}"
  desc        = local.vm_configs[each.key].description

  # VM Advanced General Settings
  onboot = true

  # VM OS Settings
  clone      = var.vm_template_name
  full_clone = true

  # VM System Settings
  agent = 0

  # VM CPU Settings
  cores    = local.vm_configs[each.key].cpu_cores
  sockets  = 1
  cpu_type = "host"

  # VM Memory Settings
  memory = local.vm_configs[each.key].memory

  # SCSI hardware
  scsihw = "virtio-scsi-single"

  # Disks
  disks {
    ide {
      ide0 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          storage  = local.vm_configs[each.key].disks.virtio0.storage
          size     = local.vm_configs[each.key].disks.virtio0.size
          iothread = try(local.vm_configs[each.key].disks.virtio0.iothread, false)
        }
      }
      virtio1 {
        disk {
          storage  = local.vm_configs[each.key].disks.virtio1.storage
          size     = local.vm_configs[each.key].disks.virtio1.size
          iothread = try(local.vm_configs[each.key].disks.virtio1.iothread, false)
        }
      }
      dynamic "virtio2" {
        for_each = local.vm_configs[each.key].disks.virtio2 != null ? [1] : []
        content {
          disk {
            storage  = local.vm_configs[each.key].disks.virtio2.storage
            size     = local.vm_configs[each.key].disks.virtio2.size
            iothread = try(local.vm_configs[each.key].disks.virtio2.iothread, true)
          }
        }
      }
    }
  }

  # USB Passthrough (conditional)
  dynamic "usbs" {
    for_each = local.vm_configs[each.key].usb != null ? [local.vm_configs[each.key].usb] : []
    content {
      usb0 {
        device {
          device_id = usbs.value.device_id
          usb3      = usbs.value.usb3
        }
      }
    }
  }

  # VM Network Settings
  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  # VM Cloud-Init Settings
  os_type   = "cloud-init"
  ipconfig0 = "ip=dhcp,ip6=dhcp"
  ciuser    = "serveradmin"
  cipassword = var.vm_serveradmin_password

  sshkeys = <<EOF
  ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDKcaStvcNp0nchCC2JBaIcBpFUmIdzrrapIhaDC8E9TzskN6Z04pRb5dShdtITeYON3zmtJlhK/gP4VqSYcarnGfc77ZwuPsc407QiPHH0B/wPM2D9PFVcR6uKOmSakFEm9tXFYFq/pCuuOxRCmjzjm/FHX7C62ipCOveoT3kCfYiUm72Y3VHfbMBx19Hpo8qwEoMxF+zCynUMkkx82nwBm4g5UDKM7aUDd0xyvTmfkE2zF3IVEjy0xmuQC4McutRtxqZcc9ImgJxL8FhdMLsb249kue1cHGRTL40y9ZlGJfegpdUAbSpQVoK1ugtO+BgQodW0hvXRwaWu7RLoSz2xam9vtSPf+eJoSMlcJX0UXns6JWZvDoywOgyDNDbXzhRBoGKZXcuwX47eDhjuWUGZHwnbHEEjkp9qYOUmnJJNmLkzGjIGAYzdbisPrvO4ll9k2ch5W/cAvo+8m1gOcychX12BcfCcadpQ9l3KcKsAJlsSufiNxVe5kthpJimCJ0s= eytha@DESKTOP-JO8S7P5
  ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDIr9SnV3KC3ztsCTYHFk09/n5G0JB6SDeN8VAhVtBKV4fhtCBxmopNb3JZLwc8HeyVE653FUC7NhQOJRWsCtfl/VETBBLWBgAFF1V6nTVv14R6DZz2zqe7fJE/nZf76tY0jeLRxrxHlesPA06JsAGIMtBBjFr6MsJYhdHm2Z93/kyaE2DQnyW/wrG888/WxxK6V25Cdrfmq4CNyGrdRb4IBnIz7TThzNoBdDDAxPs/aR9YlFI8F3jAzKnZEk8Ue2vJOjhSqyyMIp4VE/TNwSTQppIXpA8g+G8UzkfHUUT1MvUTh8pk41WfondiRLx3fEu8n3axX8lfS4k81O+pvO4D8WYEpdvXU9Kre2DEP5vzK7TWdXpWbYAtHEgzcWt0kOLVS3RFI4P7wTfAqq9hhlP1zZ/WHLF6ZFFpsjGEc1Mfzwa5KCAMGBx82o5Qa444DWN2mxBwDWXkxwEgtOitX5eypqvAdzDujDfxmB7ejTQsIw0sMKwk/CcX+GqJ/rSMhhU= eythandecker@Eythans-MBP
  EOF
}
