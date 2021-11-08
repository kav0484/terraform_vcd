#output nginx-vm {
    #value = data.vcd_vapp_vm.web-server[*].network[0].ip
#    value = data.vcd_vapp_vm.web-server
#}

#output vms {
#    #value = data.vcd_vapp_vm.web-server[*].network[0].ip
#    value = [
#        for k,v in toset(data.vcd_vapp_vm.web-server): v.network[*].ip           
#        ]
#}

#output network {
#    value = [
#        for k,v in vcd_vapp_org_network.vapp-net: v.org_network_name
#        net
#    ]
#}

/*
output "vms" {
    value = [for name in data.vcd_vapp_vm.web-server : tonumber(var.web_server.size_in_mb) < tonumber(name.internal_disk[0].size_in_mb) ? name.internal_disk[0].size_in_mb : var.web_server.size_in_mb]
}
*/

output "vms" {
    value = local.all_vm
}

output "ip" {
    value = local.all_vm[0].network[0].ip
}