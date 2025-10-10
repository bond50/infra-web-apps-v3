data "aws_availability_zones" "this" {
  state = "available"
}


locals {
  selected_azs = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.this.names, 0, 2)
}

# --- Network module ---
module "network" {
  source = "./modules/network"

  name                     = "${var.project_name}-${var.environment}"
  region                   = var.region
  vpc_cidr                 = var.vpc_cidr
  azs                      = local.selected_azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  # enable_nat_instance = var.enable_nat_instance
  # ssh_allowed_cidr    = var.ssh_allowed_cidr
  # (tags optional)
}

module "iam_instance_profile" {
  source                = "./modules/iam_instance_profile"
  project_name          = var.project_name
  environment           = var.environment
  parameter_path_prefix = "/projects/${var.project_name}/${var.environment}/"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Module      = "iam-instance-profile"
  }
}

module "compute_min_host" {
  source = "./modules/compute_min_host"

  project_name = var.project_name
  environment  = var.environment

  ami_id        = local.ami_id
  instance_type = var.instance_type

  subnet_id             = module.network.public_subnet_ids[0]
  user_data             = module.compose_bootstrap.user_data
  associate_public_ip   = true
  key_name              = var.key_name
  instance_profile_name = module.iam_instance_profile.name

  open_ssh_22      = false
  ssh_allowed_cidr = var.ssh_allowed_cidr
  open_http_80     = true
  open_https_443   = true
  # http_allowed_cidr  = "0.0.0.0/0"
  # https_allowed_cidr = "0.0.0.0/0


  tags = {
    Project     = var.project_name
    Environment = var.environment
    Role        = "app-host-min"
  }
}

module "compose_bootstrap" {
  source = "./modules/compose_bootstrap"

  project_name = var.project_name
  environment  = var.environment

  install_docker_if_missing = var.install_docker_if_missing
  stack_dir                 = var.stack_dir

  postgres_user = var.postgres_user
  postgres_db   = var.postgres_db
  postgres_port = var.postgres_port

  enable_hello_http = var.enable_hello_http
  hello_image       = var.hello_image
  hello_port        = var.hello_port
}
