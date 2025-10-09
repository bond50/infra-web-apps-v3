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


# --- Project / Environment ---
variable "project_name" { type = string }
variable "environment" {
  type    = string
  default = "prod"
}

# --- Architecture / Instance ---
variable "arch" {
  type    = string
  default = "arm64"
} # "amd64" for x86
variable "instance_type" {
  type    = string
  default = "t4g.small"
} # t3.small if amd64

# --- Volumes / EIP / Paths ---
variable "root_volume_size" {
  type    = number
  default = 20
}
variable "use_eip" {
  type    = bool
  default = false
}
variable "stack_dir" {
  type    = string
  default = "/opt/webstack"
}

# --- VPC / Subnets / NAT ---
variable "vpc_cidr" { type = string }
variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
} # empty => auto-pick first 2 AZs

# --- Postgres (local docker by default; password optional) ---
variable "postgres_user" {
  type    = string
  default = "postgres"
}
variable "postgres_password" {
  type      = string
  default   = ""
  sensitive = true
}
variable "postgres_default_db" {
  type    = string
  default = ""
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH (e.g., 1.2.3.4/32)"
  type        = string
}
