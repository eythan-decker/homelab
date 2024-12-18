variable "proxmox_node_name" {
    type = string
    description = "Name of the Proxmox Node to deploy the VMs"
    default = "pve01"
}

variable "vm_template_name" {
    type = string
    description = "Name of the Proxmox VM template image saved currently on the node"
    default = "ubuntu-server-noble"
}

variable "vm_id_list" {
  description = "A list of VM IDs to be Created/Updated."
  type        = list(number)
}

variable "vm_class_name" {
    type = string
    description = "Name of the class of VM that is being deployed. Ella, Elliot, Ezra, Emily"
    default = "pve-vm"
}

variable "vm_desc" {
    type = list(string)
    description = "Description of the VM to be displayed in the proxmox UI"
}

variable "vm_cpu_cores" {
    type = number
    description = "Ammount of CPU Cores to be used by the VM(s)"
}

variable "vm_memory" {
    type = number
    description = "Ammount of memory to be used by the VM(s)"
}

variable "vm_serveradmin_password" {
    type = string
    sensitive = true
}