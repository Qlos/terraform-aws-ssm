
resource "aws_ssm_parameter" "this" {
  # Only stable keys are declassified; parameter values remain sensitive.
  for_each = nonsensitive(toset(keys(var.parameters)))

  name        = var.parameters[each.key].name
  type        = var.parameters[each.key].type
  value       = var.parameters[each.key].value
  description = var.parameters[each.key].description
  tier        = var.parameters[each.key].tier
  key_id      = var.parameters[each.key].key_id
  tags        = merge(var.tags, var.parameters[each.key].tags)
}

resource "aws_ssm_document" "this" {
  for_each = var.documents

  name            = each.value.name
  document_type   = each.value.document_type
  content         = each.value.content
  document_format = each.value.document_format
  tags            = merge(var.tags, each.value.tags)
}

resource "aws_ssm_association" "this" {
  for_each = var.associations

  name                        = each.value.name
  association_name            = each.value.association_name
  document_version            = each.value.document_version
  parameters                  = each.value.parameters
  schedule_expression         = each.value.schedule_expression
  apply_only_at_cron_interval = each.value.apply_only_at_cron_interval

  max_concurrency                  = each.value.max_concurrency
  max_errors                       = each.value.max_errors
  compliance_severity              = each.value.compliance_severity
  sync_compliance                  = each.value.sync_compliance
  wait_for_success_timeout_seconds = each.value.wait_for_success_timeout_seconds

  dynamic "targets" {
    for_each = each.value.targets

    content {
      key    = targets.value.key
      values = targets.value.values
    }
  }

  # Resource creation order only.
  # Does not guarantee successful association execution on managed nodes.
  depends_on = [
    aws_ssm_parameter.this,
    aws_ssm_document.this
  ]
}
