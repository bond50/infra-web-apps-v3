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
