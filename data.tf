###############################################################
# data.tf
# Single caller identity (handy in modules/outputs)
###############################################################
data "aws_caller_identity" "current" {}
