###############################################################
# variables.tf
###############################################################
variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# --- Network inputs (add) ---


variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["172.20.0.0/24", "172.20.1.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["172.20.10.0/24", "172.20.11.0/24"]
}

variable "private_db_subnet_cidrs" {
  type    = list(string)
  default = ["172.20.20.0/24", "172.20.21.0/24"]
}

variable "enable_nat_instance" {
  type    = bool
  default = false
}

variable "enable_nat_gateway" {
  type    = bool
  default = false # keep cost low by default
}



variable "project_name" { type = string }
variable "environment" {
  type    = string
  default = "prod"
}

# # --- Architecture / Instance ---
# # tflint-ignore: terraform_unused_declarations
# variable "arch" {
#   type    = string
#   default = "arm64"
# } # "amd64" for x86

# # tflint-ignore: terraform_unused_declarations
# variable "instance_type" {
#   type    = string
#   default = "t4g.small"
# } # t3.small if amd64

# # --- Volumes / EIP / Paths ---
# # tflint-ignore: terraform_unused_declarations
# variable "root_volume_size" {
#   type    = number
#   default = 20
# }
# # tflint-ignore: terraform_unused_declarations
# variable "use_eip" {
#   type    = bool
#   default = false
# }

# # tflint-ignore: terraform_unused_declarations
# variable "stack_dir" {
#   type    = string
#   default = "/opt/webstack"
# }

# --- VPC / Subnets / NAT ---
variable "vpc_cidr" { type = string }
variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
} # empty => auto-pick first 2 AZs

# # --- Postgres (local docker by default; password optional) ---
# # tflint-ignore: terraform_unused_declarations
# variable "postgres_user" {
#   type    = string
#   default = "postgres"
# }
# # tflint-ignore: terraform_unused_declarations
# variable "postgres_password" {
#   type      = string
#   default   = ""
#   sensitive = true
# }
# # tflint-ignore: terraform_unused_declarations
# variable "postgres_default_db" {
#   type    = string
#   default = ""
# }


variable "ssh_allowed_cidr" {
  type    = string
  default = "197.248.148.214/32"
}
