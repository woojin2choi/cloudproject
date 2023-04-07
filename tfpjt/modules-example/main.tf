module "vpc1" {
    source    = "./modules/network"
    vpc_cidr = var.vpc_cidr
    default_tags = {
        environment = "development1",
        owner = "r&d",
        cost_centre = "1234567890"
    }
    subnet_count = 1
}


module "vpc2" {
    source    = "./modules/network"
    vpc_cidr = "172.31.0.0/16"
    default_tags = {
        environment = "development2",
        owner = "dev",
        cost_centre = "1234567890"
    }
    subnet_count = 1
}

resource "aws_instance" "test" {
    ami = "ami-0676d41f079015f32"
    instance_type = "t3.small"
}
