output "parameter_names" {
  description = "Parameter names keyed by input identifiers (values are never exported)."
  value       = { for k, p in aws_ssm_parameter.this : k => p.name }
  sensitive   = true
}

output "parameter_arns" {
  description = "Parameter ARNs keyed by input identifiers."
  value       = { for k, p in aws_ssm_parameter.this : k => p.arn }
}

output "association_ids" {
  description = "State Manager association IDs keyed by input identifiers."
  value       = { for k, a in aws_ssm_association.this : k => a.association_id }
}

output "association_names" {
  description = "Optional association names keyed by input identifiers; null when omitted."
  value       = { for k, a in aws_ssm_association.this : k => a.association_name }
}

output "document_names" {
  description = "Custom document names keyed by input identifiers."
  value       = { for k, d in aws_ssm_document.this : k => d.name }
}

output "document_arns" {
  description = "Custom document ARNs keyed by input identifiers."
  value       = { for k, d in aws_ssm_document.this : k => d.arn }
}
