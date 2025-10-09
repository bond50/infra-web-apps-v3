# A 'locals' block is used to define common, reusable variables.
# This helps keep resource names consistent and prevents typos.
locals {
  # This creates a base name by combining your project name (e.g., "myproject"),
  # environment (e.g., "staging"), and the resource type ("ec2-app").
  # The result might be "myproject-staging-ec2-app".
  name = "${var.project_name}-${var.environment}-ec2-app"
}

# ---
## EC2 IAM Role (The Identity)

# An IAM Role is like an identity you assign to an AWS service (like an EC2 server).
# It defines what the server is allowed to do within your AWS account.
resource "aws_iam_role" "ec2" {
  # Naming the role based on the local variable for consistency.
  name = "${local.name}-role"

  # The 'assume_role_policy' is a necessary JSON document that tells AWS which service 
  # is allowed to take on (or "assume") this role.
  # Here, we allow the EC2 service to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }, # Only EC2 can use this role
      Action    = "sts:AssumeRole"                   # The action that grants permission to assume the role
    }]
  })

  # Applies tags (labels for organization/billing) passed in from your variables file.
  tags = var.tags
}

# ---
## Attaching a Managed Policy (SSM Access)

# This attaches a pre-defined AWS policy to the role.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  # Specifies the role we just created. 
  # We reference it using its resource type ("aws_iam_role"), local name ("ec2"), and its property ("name").
  role = aws_iam_role.ec2.name

  # This is a critical AWS-managed policy that grants the EC2 instance the permissions 
  # it needs to communicate with the AWS Systems Manager (SSM) service.
  # This allows you to connect to the instance using Session Manager (no SSH key needed!).
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ---
## Custom Policy for Parameter Store Access

# A 'data' block is used here to build a complex JSON document *before* creating the policy.
# This document defines the exact permissions (like a permission slip).
data "aws_iam_policy_document" "param_read" {
  # Statement 1: Permissions to read AWS Parameter Store (SSM)
  statement {
    sid    = "ParamReadPrefix"
    effect = "Allow"
    # Actions allow the instance to read parameters. The '*' is a wildcard.
    actions = ["ssm:GetParameter*", "ssm:GetParametersByPath", "ssm:DescribeParameters"]
    # This is key! It restricts reading to parameters that start with a specific path
    # (e.g., /config/myproject/staging/*). This is a best practice for security.
    resources = ["arn:aws:ssm:*:*:parameter${var.parameter_path_prefix}*"]
  }

  # Statement 2: Permission to decrypt KMS-encrypted parameters
  statement {
    sid       = "KmsDecryptForSsm"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"] # KMS resource is set to all because the restriction is applied below.

    condition {
      # This condition ensures the Decrypt action is only allowed if the request 
      # came *from* the SSM service. This makes the policy secure.
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.*"]
    }
  }
}

# ---
## Creating and Attaching the Custom Policy

# This is the actual IAM Policy resource, which takes the JSON document 
# created above and publishes it in AWS IAM.
resource "aws_iam_policy" "param_read" {
  name = "${local.name}-param-read"
  # This uses the JSON output from the 'data' block to define the policy rules.
  policy = data.aws_iam_policy_document.param_read.json
}

# Attaches the custom policy (param_read) to the EC2 role (aws_iam_role.ec2).
resource "aws_iam_role_policy_attachment" "param_read_attach" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.param_read.arn # ARN is the unique identifier for the policy
}

# ---
## IAM Instance Profile (The Link to EC2)

# An Instance Profile is the container that links the IAM Role to the actual EC2 instance.
# When you launch an EC2 instance, you assign the Instance Profile, not the Role directly.
resource "aws_iam_instance_profile" "profile" {
  name = "${local.name}-profile"
  role = aws_iam_role.ec2.name # Links the profile to the EC2 IAM Role
  tags = var.tags
}
