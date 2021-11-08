terraform {
    backend "consul" {} 
    
    required_providers {
      vcd = {
        source = "vmware/vcd"
        version = "3.0.0"
    }
    local = {
      source = "hashicorp/local"
      version = "2.1.0"
    }
  }
}

provider "vcd" {
    url                  = var.auth_provider.url
    user                 = var.auth_provider.user
    password             = var.auth_provider.password
    org                  = var.auth_provider.org
    vdc                  = var.auth_provider.vdc
    allow_unverified_ssl = var.auth_provider.allow_unverified_ssl
    max_retry_timeout    = var.auth_provider.max_retry_timeout
}

  data "vcd_edgegateway" "egw" {
    name = var.vcd_edge_gateway
  }


## Template
resource "vcd_catalog" "template-catalog" {
  org              = var.auth_provider.org

  name             = var.vcd_catalog_name
  delete_recursive = "true"
  delete_force     = "true"
}

resource "vcd_catalog_item" "template" {
  org     = var.auth_provider.org
  catalog = vcd_catalog.template-catalog.name

  name                 = var.vcd_ova_template_name
  ova_path             = var.vcd_template_local_path
  upload_piece_size    = 10
  show_upload_progress = true
}

##Networks
resource "vcd_network_routed" "subnets" {
  count           = length(var.subnets)
  name            = var.subnets[count.index].name
  edge_gateway    = var.vcd_edge_gateway 
  gateway         = var.subnets[count.index].gateway

  static_ip_pool {
    start_address = var.subnets[count.index].pool_start_address
    end_address   = var.subnets[count.index].pool_end_address
  }
}

##vapps
resource "vcd_vapp" "web" {
    name                = var.vapp_name
}

resource "vcd_vapp_org_network" "vapp-net" {
  count = length(var.subnets)
  vapp_name        = vcd_vapp.web.name
  org_network_name = vcd_network_routed.subnets[count.index].name
}

############# Create VM ######################

#create web-servers
resource "vcd_vapp_vm" "web" {
  count = var.web_server.instance_count
  vapp_name           = vcd_vapp.web.name
  name                = "${var.web_server.name}${count.index}"

  catalog_name        = var.vcd_catalog_name
  template_name       = vcd_catalog_item.template.name

  memory              = var.web_server.memory
  cpus                = var.web_server.cpus
  cpu_cores           = var.web_server.cpu_cores

  computer_name       = "${var.web_server.name}${count.index}"

  metadata            = "${var.web_server.metadata}"

  dynamic "network" {
    for_each  = var.web_server.network
    content {
      type               = "org"
      name               = network.value
      ip_allocation_mode = "POOL"
    }
  }  
    customization {
    enabled                    = true
    force                      = true
    change_sid                 = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.vcd_vm_admin_password
    
  }
 
}

data "vcd_vapp_vm" "web-server" {
  count               = var.web_server.instance_count
  vapp_name           = vcd_vapp.web.name
  name                = vcd_vapp_vm.web[count.index].name
}

/*
resource "vcd_vm_internal_disk" "web-servers" {
  count           = length(data.vcd_vapp_vm.web-server)
  vapp_name       = vcd_vapp.web.name
  vm_name         = data.vcd_vapp_vm.web-server[count.index].computer_name
  bus_type        = data.vcd_vapp_vm.web-server[count.index].internal_disk[0].bus_type
  #size_in_mb      = [for vm in data_vm.vcd_vapp_vm.web-server : tonumber(var.web_server.size_in_mb) < tonumber(vm.internal_disk[0].size_in_mb) ? vm.internal_disk[0].size_in_mb : var.web_server.size_in_mb]
  size_in_mb      = data.vcd_vapp_vm.web-server[count.index].internal_disk[0].size_in_mb
  bus_number      = data.vcd_vapp_vm.web-server[count.index].internal_disk[0].bus_number
  unit_number     = data.vcd_vapp_vm.web-server[count.index].internal_disk[0].unit_number
  #storage_profile = data.vcd_vapp_vm.web-server[count.index].internal_disk[0].storage_profile
  allow_vm_reboot = true
}
*/

#create db-servers
resource "vcd_vapp_vm" "db" {
  count               = var.db_server.instance_count
  vapp_name           = vcd_vapp.web.name
  name                = "${var.db_server.name}${count.index}"
  
  catalog_name        = var.vcd_catalog_name
  template_name       = vcd_catalog_item.template.name

  memory              = var.db_server.memory
  cpus                = var.db_server.cpus
  cpu_cores           = var.db_server.cpu_cores


  computer_name       = "${var.db_server.name}${count.index}"

  metadata            = "${var.db_server.metadata}"

  dynamic "network" {
    for_each  = var.web_server.network
    content {
      type               = "org"
      name               = network.value
      ip_allocation_mode = "POOL"
    }
  }  
    customization {
      enabled                    = true
      force                      = false
      change_sid                 = true
      allow_local_admin_password = true
      auto_generate_password     = false
      admin_password             = var.vcd_vm_admin_password
  }
}

data "vcd_vapp_vm" "db" {
  count               = var.db_server.instance_count
  vapp_name           = vcd_vapp.web.name
  name                = vcd_vapp_vm.db[count.index].name
}

/*
resource "vcd_vm_internal_disk" "db" {
  vapp_name       = vcd_vapp.web.name
  vm_name         = "db0"
  bus_type        = "paravirtual"
  #size_in_mb      = [for vm in data_vm.vcd_vapp_vm.web-server : tonumber(var.web_server.size_in_mb) < tonumber(vm.internal_disk[0].size_in_mb) ? vm.internal_disk[0].size_in_mb : var.web_server.size_in_mb]
  size_in_mb      = 20000
  bus_number      = 0
  unit_number     = 0
  storage_profile = "DVT-vCD VM Storage Policy"
  allow_vm_reboot = true
  depends_on =  [null_resource.ansible]
}
*/
#Объединяем список всех локальных машин со всеми параметрами
locals{
  all_vm = concat(data.vcd_vapp_vm.web-server, data.vcd_vapp_vm.db)
}



#########LOAD BALANCE####################

##Enable Load balance
resource "vcd_edgegateway_settings" "egw-settings" {
  edge_gateway_id = data.vcd_edgegateway.egw.id
  lb_enabled = true
  lb_acceleration_enabled = true
  lb_logging_enabled      = false
}

##Create profile
resource "vcd_lb_app_profile" "tcp" {
  edge_gateway = var.vcd_edge_gateway
  name = var.load_balancer.profile["name"]
  type = var.load_balancer.profile["type"]
}

##Create pool
resource "vcd_lb_server_pool" "web-servers" {
  edge_gateway = var.vcd_edge_gateway

  name = var.load_balancer.pool["name"]
  algorithm = var.load_balancer.pool["algorithm"]

  dynamic "member" {
    for_each = toset(data.vcd_vapp_vm.web-server)
    content {
    condition = "enabled"
    name = member.value.name
    ip_address = member.value.network[0].ip
    port = var.load_balancer.pool["port"]
    monitor_port  = var.load_balancer.pool["monitor_port"]
    weight = 1
    }
  }
}

##Create virtual server
resource "vcd_lb_virtual_server" "http" {
  edge_gateway = var.vcd_edge_gateway

  name = var.load_balancer.virtual_server["name"]
  ip_address = data.vcd_edgegateway.egw.default_external_network_ip
  protocol   = var.load_balancer.virtual_server["protocol"]
  port       = var.load_balancer.virtual_server["ext_port"]

  app_profile_id = "${vcd_lb_app_profile.tcp.id}"
  server_pool_id = "${vcd_lb_server_pool.web-servers.id}"
}



###############FIREWALL###############
resource "vcd_nsxv_firewall_rule" "outbound-edge-firewall" {

  edge_gateway 	             = var.vcd_edge_gateway
  name 		                   = "outbound"
  source { ip_addresses      = var.subnets[*].subnet }
  destination { ip_addresses = ["any"] }
  service {
    protocol                 = "any"
  }
}

resource "vcd_nsxv_firewall_rule" "lb-rule-firewall" {

  edge_gateway 	             = var.vcd_edge_gateway
  name 		                   = "lb-web"
  source { ip_addresses      = ["any"] }
  destination { ip_addresses = [data.vcd_edgegateway.egw.default_external_network_ip] }
  service {
    protocol                 = "tcp"
    port                     = 8080 
  }
}

resource "vcd_nsxv_snat" "nat" {
  edge_gateway        = var.vcd_edge_gateway

  network_type        = "ext"
  network_name        = join(",",data.vcd_edgegateway.egw.external_network[*].name) 

  original_address   = "192.168.11.0/24"  
  translated_address = data.vcd_edgegateway.egw.default_external_network_ip
}

#DNAT TO WEB1
resource "vcd_nsxv_firewall_rule" "dnat-ssh" {
  name = "dnat-ssh"
  edge_gateway      = var.vcd_edge_gateway
  source {
    ip_addresses    = ["any"]
    }
  destination {
    ip_addresses    = [data.vcd_edgegateway.egw.default_external_network_ip]
    }

  dynamic "service" {
    for_each = local.all_vm
    content {
    protocol  = "tcp"
    port      = var.start_ssh_port + service.key
    }
  }
}

resource "vcd_nsxv_dnat" "dnat-ssh" {
  count = length(local.all_vm)
  edge_gateway = var.vcd_edge_gateway
  network_name = join(",",data.vcd_edgegateway.egw.external_network[*].name)
  network_type = "ext"

  enabled = true
  logging_enabled = false
  description = "DNAT to ${local.all_vm[count.index].name} rule"

  original_address   = data.vcd_edgegateway.egw.default_external_network_ip
  original_port      = var.start_ssh_port + count.index

  translated_address = local.all_vm[count.index].network[0].ip
  translated_port    = 22
  protocol           = "tcp"

}

#data "template_file" "dev_hosts" {
#  content = templatefile("${papath.module}/hosts.tpl")
#}

#resource "null_resource" "ansible_inventory_hosts" {
#  count = "${length(local.all_vm)}"
##  provisioner "local-exec" {
#    command = "echo ${element(local.all_vm.network[*].ip, count.index)} >> 1.txt"
#  }
#}
