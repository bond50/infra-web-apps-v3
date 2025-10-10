# ---
# Local Variables
# ---

# The 'locals' block defines variables that are calculated and reused throughout the configuration.
locals {
  # 1. Base Name: Creates a consistent naming prefix (e.g., "myproject-dev-host-min")
  # by combining input variables.
  name = "${var.project_name}-${var.environment}-host-min"

  # 2. Tags: Defines a standard set of AWS tags (metadata) for resources.
  # 'merge' combines a base set of tags (Project, Environment, Module) 
  # with any custom tags provided by the user (var.tags).
  tags = merge({
    Project     = var.project_name
    Environment = var.environment
    Module      = "compute-min-host"
  }, var.tags)
}

# ---
# Security Group (Network Firewall)
# ---

# The Security Group (SG) acts as a virtual firewall for the EC2 instance.
# By default, this is a "minimal" SG: it allows no incoming traffic (ingress) 
# but allows all outgoing traffic (egress).
resource "aws_security_group" "this" {
  name        = "${local.name}-sg"
  description = "Minimal host SG"
  # Gets the VPC ID needed for the SG from the Subnet data source defined below.
  vpc_id = data.aws_subnet.selected.vpc_id
  dynamic "ingress" {
    for_each = var.open_http_80 ? [1] : []
    content {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = [var.http_allowed_cidr]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # --- NEW: optional HTTPS (443)
  dynamic "ingress" {
    for_each = var.open_https_443 ? [1] : []
    content {
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = [var.https_allowed_cidr]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # Ingress (Incoming) Rules: Defines what traffic is allowed *into* the EC2 instance.
  dynamic "ingress" {
    # The 'dynamic' block conditionally creates the ingress rule.
    # It only executes if the input variable 'var.open_ssh_22' is true.
    for_each = var.open_ssh_22 ? [1] : []
    content {
      description = "SSH"
      from_port   = var.ssh_port
      to_port     = var.ssh_port
      protocol    = "tcp"
      # The IP range (CIDR) from which SSH access is allowed. This should be highly restricted.
      cidr_blocks = [var.ssh_allowed_cidr]
    }
  }

  # Egress (Outgoing) Rules: Defines what traffic the EC2 instance can send *out*.
  egress {
    description      = "All egress"
    from_port        = 0             # Start port 0 (all ports)
    to_port          = 0             # End port 0 (all ports)
    protocol         = "-1"          # Protocol -1 means "all protocols"
    cidr_blocks      = ["0.0.0.0/0"] # All IPv4 destinations
    ipv6_cidr_blocks = ["::/0"]      # All IPv6 destinations
    # This block allows the instance to connect to anything on the internet/VPC.
  }

  tags = local.tags
}

# ---
# Data Source (Retrieving Existing Information)
# ---

# A 'data' block is used to fetch information about an existing resource in AWS, 
# rather than creating a new one.
data "aws_subnet" "selected" {
  # Looks up the subnet in AWS using the ID provided in the input variables.
  id = var.subnet_id
  # This data is used to get the 'vpc_id' for the Security Group above.
}

# ---
# EC2 Instance (The Server)
# ---

# This resource creates the actual AWS Elastic Compute Cloud (EC2) instance (virtual server).
resource "aws_instance" "this" {
  ami           = var.ami_id        # The Amazon Machine Image (OS/software template)
  instance_type = var.instance_type # The size/power of the server (e.g., 't3.micro')
  subnet_id     = var.subnet_id     # Where the instance will be placed in the network
  # Links the server to the Security Group defined earlier.
  vpc_security_group_ids = [aws_security_group.this.id]
  # Determines if the server should receive a public IP for internet access.
  associate_public_ip_address = var.associate_public_ip

  # Conditional Key Name: Assigns an SSH key pair for login if a name is provided.
  # If the variable is an empty string (""), it sets the value to 'null', which AWS treats as unset.
  key_name = var.key_name != "" ? var.key_name : null
  # Conditional IAM Profile: Assigns an IAM profile for permissions if a name is provided.
  iam_instance_profile        = var.instance_profile_name != "" ? var.instance_profile_name : null
  user_data                   = var.user_data != "" ? var.user_data : null
  user_data_replace_on_change = var.user_data_replace_on_change

  # Root Block Device: Configuration for the server's main hard drive (EBS volume).
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3" # A modern, cost-effective volume type.
    delete_on_termination = true  # Destroy the disk when the instance is terminated.
    encrypted             = true  # Encrypts the disk for security (best practice).
  }

  # No user_data here (scripts that run on first boot are excluded to keep this module minimal).

  # Combines the standard tags with a specific 'Name' tag for display in the AWS Console.
  tags = merge(local.tags, { Name = local.name })
}
