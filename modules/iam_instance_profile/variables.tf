variable "project_name" { type = string }
variable "environment" { type = string }

# e.g. "/projects/web-apps/prod/"
variable "parameter_path_prefix" {
  type        = string
  description = "SSM Parameter Store prefix the instance may read (recursive)"
}

variable "tags" {
  type    = map(string)
  default = {}
}
