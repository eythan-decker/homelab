variable "proxmox_node_name" {
  type        = string
  description = "Name of the Proxmox Node to deploy the VMs"
  default     = "pve01"
}

variable "vm_template_name" {
  type        = string
  description = "Name of the Proxmox VM template image saved currently on the node"
  default     = "ubuntu-server-noble"
}

variable "vm_class_name" {
  type        = string
  description = "Name of the class of VM that is being deployed (e.g., pve-ella, pve-elliot)"
}

variable "class_defaults" {
  description = "Default resource allocation for this VM class"
  type = object({
    cpu_cores = number
    memory    = number
    disks = object({
      virtio0 = object({
        size    = string
        storage = string
      })
      virtio1 = object({
        size    = string
        storage = string
      })
    })
  })
}

variable "vms" {
  description = "Map of VM definitions keyed by VM ID"
  type = map(object({
    description = string
    cpu_cores   = optional(number)
    memory      = optional(number)
    disks = optional(object({
      virtio0 = optional(object({
        size     = string
        storage  = string
        iothread = optional(bool, false)
      }))
      virtio1 = optional(object({
        size     = string
        storage  = string
        iothread = optional(bool, false)
      }))
      virtio2 = optional(object({
        size     = string
        storage  = string
        iothread = optional(bool, false)
      }))
    }))
    usb = optional(object({
      device_id = string
      usb3      = optional(bool, false)
    }))
  }))
}

variable "vm_serveradmin_password" {
  type      = string
  sensitive = true
}
