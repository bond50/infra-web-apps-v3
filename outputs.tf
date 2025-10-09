# root/outputs.tf


output "account_id" { value = data.aws_caller_identity.current.account_id }

# From compute_app_host module (now exported properly)
# output "web_instance_id" { value = module.compute_app_host.id }
# output "web_instance_arn" { value = module.compute_app_host.arn }
# output "web_public_ip" { value = module.compute_app_host.public_ip }
# output "eip_public_ip" { value = module.compute_app_host.eip_public_ip }
# output "origin_public_ip" { value = module.compute_app_host.origin_public_ip }

# # From stack_ssm (already exported there)
# output "ssm_render_doc" { value = module.stack_ssm.ssm_document_name }
