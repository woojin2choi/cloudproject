variable "vpc_cidr" {
    type = string
    description = "The CIDR block for the VPC"
    default = "10.0.0.0/16"
    
    validation {
        condition = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}($|/(16|24))$",var.vpc_cidr))
        error_message = "Please ensure a valid CIDR has been entered with range /16 or /24."
    }
}

variable default_tags {
    type = object({
        environment = string
        owner = string
        cost_centre = string
    })
    description = "Default set of tags to apply to resources"
    default = {
        environment = "development",
        owner = "r&d",
        cost_centre = "1234567890"
    }
    
    validation {
        condition = length(var.default_tags.cost_centre) == 10
        error_message = "Please ensure a valid 10 digit cost centre code has been entered."
    }
}

variable subnet_count {
  type = number
  default = 2
}
