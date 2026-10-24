
variable "tags" {
  description = "Common tags for SSM parameters and documents. Resource tags take precedence."
  type        = map(string)
  default     = {}
}

variable "parameters" {
  description = "SSM parameters keyed by stable identifiers. Values, including SecureString, are stored in Terraform state."

  type = map(object({
    name        = string
    type        = optional(string, "String")
    value       = string
    description = optional(string)
    tier        = optional(string, "Standard")
    key_id      = optional(string)
    tags        = optional(map(string), {})
  }))

  default   = {}
  sensitive = true

  validation {
    condition = alltrue([
      for p in values(var.parameters) :
      contains(["String", "StringList", "SecureString"], p.type) &&
      contains(["Standard", "Advanced", "Intelligent-Tiering"], p.tier) &&
      (p.key_id == null || p.type == "SecureString")
    ])

    error_message = "Use a supported parameter type/tier; key_id is only valid for SecureString."
  }
}

variable "associations" {
  description = "SSM State Manager associations keyed by stable identifiers, targeting EC2 instances by tags."

  type = map(object({
    name             = string
    association_name = optional(string)
    document_version = optional(string)
    parameters       = optional(map(string), {})
    targets = list(object({
      key    = string
      values = list(string)
    }))

    schedule_expression         = optional(string)
    apply_only_at_cron_interval = optional(bool, false)

    max_concurrency                  = optional(string)
    max_errors                       = optional(string)
    compliance_severity              = optional(string, "UNSPECIFIED")
    sync_compliance                  = optional(string, "AUTO")
    wait_for_success_timeout_seconds = optional(number)
  }))

  default = {}

  validation {
    condition = alltrue([
      for a in values(var.associations) :
      length(a.targets) > 0 &&
      length(a.targets) <= 5 &&
      alltrue([
        for t in a.targets :
        can(regex("^tag:.+$", t.key)) &&
        length(t.values) > 0 &&
        length(t.values) <= 5
      ])
    ])

    error_message = "Each association requires 1-5 tag targets (key = tag:<name>), each containing 1-5 values."
  }

  validation {
    condition = alltrue([
      for a in values(var.associations) :
      !a.apply_only_at_cron_interval ||
      (
        a.schedule_expression != null &&
        can(regex("^cron\\(", a.schedule_expression))
      )
    ])

    error_message = "apply_only_at_cron_interval requires a cron schedule_expression."
  }

  validation {
    condition = alltrue([
      for a in values(var.associations) :
      a.max_concurrency == null ||
      can(regex("^([1-9][0-9]*|[1-9][0-9]?%|100%)$", a.max_concurrency))
    ])

    error_message = "max_concurrency must be a positive integer or a percentage from 1% to 100%."
  }

  validation {
    condition = alltrue([
      for a in values(var.associations) :
      a.max_errors == null ||
      can(regex("^([0-9]+|[0-9]{1,2}%|100%)$", a.max_errors))
    ])

    error_message = "max_errors must be a non-negative integer or a percentage from 0% to 100%."
  }

  validation {
    condition = alltrue([
      for a in values(var.associations) :
      contains(
        ["UNSPECIFIED", "LOW", "MEDIUM", "HIGH", "CRITICAL"],
        a.compliance_severity
      )
    ])

    error_message = "compliance_severity must be UNSPECIFIED, LOW, MEDIUM, HIGH or CRITICAL."
  }

  validation {
    condition = alltrue([
      for a in values(var.associations) :
      contains(["AUTO", "MANUAL"], a.sync_compliance)
    ])

    error_message = "sync_compliance must be AUTO or MANUAL."
  }

  validation {
    condition = alltrue([
      for a in values(var.associations) :
      a.wait_for_success_timeout_seconds == null ||
      (
        a.wait_for_success_timeout_seconds > 0 &&
        floor(a.wait_for_success_timeout_seconds) == a.wait_for_success_timeout_seconds
      )
    ])

    error_message = "wait_for_success_timeout_seconds must be a positive integer."
  }
}

variable "documents" {
  description = "Optional custom SSM documents keyed by stable identifiers. AWS-managed documents require no entry."

  type = map(object({
    name            = string
    document_type   = string
    content         = string
    document_format = optional(string, "JSON")
    tags            = optional(map(string), {})
  }))

  default = {}

  validation {
    condition = alltrue([
      for d in values(var.documents) :
      contains(["JSON", "YAML"], d.document_format)
    ])

    error_message = "document_format must be JSON or YAML."
  }

  validation {
    condition = alltrue([
      for d in values(var.documents) :
      contains(
        ["Command", "Automation", "Policy", "Session", "Package", "ApplicationConfiguration", "ApplicationConfigurationSchema", "ChangeCalendar", "ProblemAnalysis", "ProblemAnalysisTemplate", "DeploymentStrategy"],
        d.document_type
      )
    ])

    error_message = "Unsupported SSM document_type."
  }
}
