variable "auth_provider" {
    type = object ({
        url                  = string
        org                  = string  
        vdc                  = string  
        user                 = string
        password             = string
        max_retry_timeout    = number
        allow_unverified_ssl = bool
    })
}

variable "vcd_catalog_name" {
    description = "Catalog  templates of vm"
}

variable "vapp_name" {
    description = "vapp name"
}

variable "vcd_edge_gateway" {
    description = "Edge Gateway"
}

variable "vcd_vm_admin_password" {
    description = "Admin password for vm"
}

variable "vcd_ova_template_name" {
    description = "Имя шаблона виртуальной машины"
}

variable "vcd_template_local_path" {
    description = "Путь к шаблону виртуальной машины"
}

variable "start_ssh_port" {
    default = 20025
    description = "Начальный порт ssh для dnat"
}

variable "subnets" {
    type = list(object({ 
        name               = string
        subnet             = string
        gateway            = string
        pool_start_address = string
        pool_end_address   = string
    }))
}

variable "web_server" {
    type = object({
        instance_count      = number
        name                = string
        memory              = number
        cpus                = number
        cpu_cores           = number
        network             = list(string)
        size_in_mb          = number
        metadata            = map(string)
    })

    default = ({
        instance_count      = 1
        name                = "web"
        memory              = 1024
        cpus                = 1
        cpu_cores           = 1
        size_in_mb          = 0
#Список сетей вм. Первая сеть в списке становиться сетью по умолчанию
        network             = [""]
        metadata            = {
            "ansible_group" = ""
        } 
    })
}

variable "db_server" {
    type = object({
        instance_count      = number
        name                = string
        memory              = number
        cpus                = number
        cpu_cores           = number
        size_in_mb          = number
#Список сетей вм. Первая сеть в списке становиться сетью по умолчанию
        network             = list(string)
        metadata            = map(string)
          
    })

    default = ({
        instance_count      = 1
        name                = "db"
        memory              = 1024
        cpus                = 1
        cpu_cores           = 1
        size_in_mb          = 0
        network             = [""]
        metadata            = {
            "ansible_group" = ""
        }   
    })
}

variable "load_balancer" {
    type = object({
        profile         = map(string)
        pool            = map(string)
        virtual_server  = map(string)
    })

    default = ({

        profile = {
            "name"              = ""
            "type"              = "tcp"
        }
        pool = {
            "name"              = ""
            "algorithm"         = "round-robin"
            "port"              = "80"
            "monitor_port"      = "80"
        }
        virtual_server = {
            name     = ""
            protocol = ""
            ext_port = 80
        }
    })
}