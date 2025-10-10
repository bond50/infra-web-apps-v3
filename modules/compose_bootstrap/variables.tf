variable "project_name" { type = string }
variable "environment" { type = string }

variable "stack_dir" {
  type    = string
  default = "/opt/webstack"
}

# Docker install toggle (Ubuntu official flow)
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
  default   = "" # if empty we generate & store to SSM
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


# Optional Hello service (tiny HTTP 200 on :hello_port)
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
