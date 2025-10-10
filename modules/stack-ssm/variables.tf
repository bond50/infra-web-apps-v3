# Module-scoped inputs (all used)

variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "instance_id" {
  type = string
}

# Where we render compose + runtime state on the box
variable "stack_dir" {
  type    = string
  default = "/opt/webstack"
}

# Install Docker using the official Ubuntu docs sequence (toggle)
variable "install_docker_if_missing" {
  type    = bool
  default = true
}

# Postgres 17 container knobs (host-level DB service)
variable "postgres_user" {
  type    = string
  default = "postgres"
}
variable "postgres_password" {
  description = "If empty, we generate a strong password and store it in SSM (SecureString)."
  type        = string
  default     = ""
  sensitive   = true
}
variable "postgres_db" {
  type    = string
  default = "appdb"
}
variable "postgres_port" {
  type    = number
  default = 5432
}

# Optional: simple HTTP container to prove Docker works
variable "enable_hello_http" {
  type    = bool
  default = false
}
variable "hello_image" {
  type    = string
  default = "nginxdemos/hello:plain-text"
}
variable "hello_port" {
  type    = number
  default = 8080
}
