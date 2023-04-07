variable "vpc_cidr" {
    type = string
    description = "The CIDR block for the VPC"
    default = "10.0.0.0/16"
    
    validation {
        condition = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}($|/(16|24))$",var.vpc_cidr))
        error_message = "Please ensure a valid CIDR has been entered with range /16 or /24."
    }
}
