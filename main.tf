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

  enable_nat_gateway  = var.enable_nat_gateway
  enable_nat_instance = var.enable_nat_instance
  ssh_allowed_cidr    = var.ssh_allowed_cidr
  # (tags optional)
}


# module "compute_app_host" {
#   # FIX: directory name uses underscore, not hyphen
#   source = "./modules/compute_app_host"

#   project_name     = var.project_name
#   environment      = var.environment
#   ami_id           = data.aws_ami.ubuntu.id
#   instance_type    = var.instance_type
#   ssh_allowed_cidr = var.ssh_allowed_cidr
#   # Assumes your network module exports public_subnet_ids.
#   # If your output name differs, adjust here.
#   subnet_id = module.network.public_subnet_ids[0]

#   # TEMP: let the compute module create its own SG for now
#   # security_group_id     = module.security_group.id  # REMOVE this line

#   # TEMP: skip IAM instance profile until we add it as a module
#   # instance_profile_name = aws_iam_instance_profile.ec2.name   # REMOVE this line

#   root_volume_size      = var.root_volume_size
#   associate_public_ip   = true
#   use_eip               = var.use_eip
#   instance_profile_name = aws_iam_instance_profile.ec2_ssm.name

#   key_name              = "" # use SSM Session Manager
#   stack_dir             = var.stack_dir
#   enable_local_postgres = true # mandatory now
# }


# module "stack_ssm" {
#   source       = "./modules/stack-ssm"
#   project_name = var.project_name
#   environment  = var.environment

#   # FIX: the compute module outputs "id" (not "instance_id")
#   instance_id = module.compute_app_host.id

#   stack_dir         = var.stack_dir
#   postgres_user     = var.postgres_user
#   postgres_password = var.postgres_password
#   postgres_db       = var.postgres_default_db != "" ? var.postgres_default_db : "${var.project_name}_db"
#   postgres_port     = 5432
# }
