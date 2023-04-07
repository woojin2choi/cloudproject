locals {
    subnet_addresses = cidrsubnets(var.vpc_cidr,8,8)
    subnet_new_bits = 8
}
