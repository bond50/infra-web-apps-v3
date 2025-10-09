# add near the top with your other variables
variable "region" {
  type = string
}


variable "name" { type = string } # e.g. "${project_name}-${environment}"
variable "environment" {
  type    = string
  default = "prod"
}


variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }

variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_subnet_cidrs" { type = list(string) }
variable "private_db_subnet_cidrs" { type = list(string) }

variable "enable_nat_gateway" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_nat_instance" {
  type    = bool
  default = false
}

# CIDR allowed to SSH to the NAT instance (only used if NAT instance is enabled)
variable "ssh_allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
