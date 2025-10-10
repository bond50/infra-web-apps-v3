variable "project_name" { type = string }
variable "environment" { type = string }

# Where we place compose/runtime/logs on the host
variable "stack_dir" {
  type    = string
  default = "/opt/webstack"
}

# Install Docker via official Ubuntu flow if missing
variable "install_docker_if_missing" {
  type    = bool
  default = true
}

# Postgres knobs (host-local DB)
variable "postgres_user" {
  type    = string
  default = "postgres"
}
variable "postgres_password" {
  type      = string
  default   = "" # if empty -> generate + store in SSM
  sensitive = true
}
variable "postgres_db" {
  type    = string
  default = "appdb"
}
variable "postgres_port" {
  type    = number
  default = 5432
}

# Optional hello service
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
variable "instance_id" {
  type        = string
  description = "EC2 instance ID targeted by the compose bootstrap association"
}
