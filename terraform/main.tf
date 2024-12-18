# Proxmox Full-Clone
# ---

module "ella_class_vms" {
  source = "./modules/proxmox_vms"

  vm_id_list = ["101", "102", "103", "104"]
  vm_class_name = "pve-ella"
  vm_template_name = "ubuntu-server-noble"
  proxmox_node_name = "pve01"
  vm_desc = ["Ella Class VM. k3s master1", "Ella Class VM. k3s master2", "Ella Class VM. k3s master3", "Ella Class VM. Rancher Admin Cluster"]
  vm_cpu_cores = 4
  vm_memory = 4096
  vm_serveradmin_password = var.serveradmin_password

}

module "elliot_class_vms" {
  source = "./modules/proxmox_vms"

  vm_id_list = ["120"]
  vm_class_name = "pve-elliot"
  vm_template_name = "ubuntu-server-noble"
  proxmox_node_name = "pve01"
  vm_desc = ["Elliot Class VM. k3s agent1"]
  vm_cpu_cores = 6
  vm_memory = 16384
  vm_serveradmin_password = var.serveradmin_password

}