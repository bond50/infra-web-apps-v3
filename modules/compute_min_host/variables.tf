variable "project_name" { type = string }
variable "environment" { type = string }

variable "ami_id" { type = string }
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "subnet_id" { type = string }

variable "associate_public_ip" {
  type    = bool
  default = true
}

variable "key_name" {
  type    = string
  default = ""
}

# Optional IAM instance profile name (from step 2a)
variable "instance_profile_name" {
  type    = string
  default = ""
}

# SSH closed by default; enable explicitly when needed
variable "open_ssh_22" {
  type    = bool
  default = false
}
variable "ssh_port" {
  type    = number
  default = 22
}
variable "ssh_allowed_cidr" {
  type    = string
  default = "0.0.0.0/32" # effectively disabled until you set it
}

variable "tags" {
  type    = map(string)
  default = {}
}


# Toggle HTTP/HTTPS ingress (default: closed)
variable "open_http_80" {
  type    = bool
  default = false
}
variable "open_https_443" {
  type    = bool
  default = false
}

# Allowed CIDRs when open (defaults: world)
variable "http_allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
variable "https_allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

# Optional cloud-init / user-data to run at boot
variable "user_data" {
  type        = string
  default     = ""
  description = "Cloud-init user-data to run on instance boot (empty = none)."
}

# Ensure instance is replaced when user_data changes (so script reruns)
variable "user_data_replace_on_change" {
  type    = bool
  default = true
}

