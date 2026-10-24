
# Interface reference

Terraform interface documentation for the Qlos `terraform-aws-ssm` module.

The module manages:

- AWS SSM Parameter Store parameters
- AWS SSM State Manager associations
- Custom AWS SSM documents

All resource collections default to empty maps.

## Requirements

| Component | Version |
|---|---|
| Terraform | >= 1.3.0 |
| OpenTofu | Compatible versions |
| AWS Provider | >= 5.0 |

Configuration validated using OpenTofu 1.12.1 and AWS providers 5.100.0 and 6.70.0.

## Inputs

### tags

**Type:** `map(string)`

**Default:** `{}`

Common tags applied to SSM parameters and custom documents.

Per-resource tags take precedence over common tags.

### parameters

**Type:** `map(object)`

**Default:** `{}`

**Sensitive:** Yes

Creates AWS SSM Parameter Store parameters.

Each parameter is identified by a stable map key.

#### Parameter attributes

| Attribute | Type | Required | Default |
|---|---|---|---|
| `name` | string | Yes | — |
| `value` | string | Yes | — |
| `type` | string | No | `"String"` |
| `description` | string | No | `null` |
| `tier` | string | No | `"Standard"` |
| `key_id` | string | No | `null` |
| `tags` | map(string) | No | `{}` |

Supported parameter types:

- `String`
- `StringList`
- `SecureString`

Supported parameter tiers:

- `Standard`
- `Advanced`
- `Intelligent-Tiering`

`key_id` is only valid for SecureString parameters.

Example:

```hcl
parameters = {
  api_url = {
    name  = "/example/prod/api-url"
    value = "https://api.example.com"
  }
}
```

Parameter values, including SecureString values, are stored in Terraform state.

### associations

**Type:** `map(object)`

**Default:** `{}`

Creates SSM State Manager associations.

Each association is identified by a stable map key.

#### Association attributes

| Attribute | Type | Required | Default |
|---|---|---|---|
| `name` | string | Yes | — |
| `targets` | list(object) | Yes | — |
| `association_name` | string | No | `null` |
| `document_version` | string | No | `null` |
| `parameters` | map(string) | No | `{}` |
| `schedule_expression` | string | No | `null` |
| `apply_only_at_cron_interval` | bool | No | `false` |
| `max_concurrency` | string | No | `null` |
| `max_errors` | string | No | `null` |
| `compliance_severity` | string | No | `"UNSPECIFIED"` |
| `sync_compliance` | string | No | `"AUTO"` |
| `wait_for_success_timeout_seconds` | number | No | `null` |

#### Targets

Targets are defined as:

```hcl
targets = [
  {
    key    = "tag:Name"
    values = ["example-ecs-worker"]
  }
]
```

Target attributes:

| Attribute | Type | Required |
|---|---|---|
| `key` | string | Yes |
| `values` | list(string) | Yes |

The module currently accepts tag-based targets only.

Input validation allows:

- 1–5 target blocks per association.
- 1–5 values per target block.
- Target keys matching `tag:<name>`.

AWS service restrictions still apply.

The module does not accept direct EC2 Instance ID targeting.

#### Association parameters

Association parameters are passed to the SSM document as:

```hcl
parameters = {
  action = "Install"
  name   = "AmazonCloudWatchAgent"
}
```

The module uses `map(string)` for document parameters.

Required parameter names and values depend on the SSM document being executed.

#### Scheduling

`schedule_expression` supports AWS Systems Manager-compatible rate or cron expressions.

Example:

```hcl
schedule_expression = "rate(1 day)"
```

When `apply_only_at_cron_interval = true`, a cron expression is required.

Example:

```hcl
schedule_expression         = "cron(0 2 ? * SUN *)"
apply_only_at_cron_interval = true
```

#### Concurrency

`max_concurrency` controls how many targets can execute an association concurrently.

Accepted values include positive integers and percentages from 1% to 100%.

Example:

```hcl
max_concurrency = "1"
```

#### Error threshold

`max_errors` configures the allowed error threshold.

Accepted values include non-negative integers and percentages from 0% to 100%.

Example:

```hcl
max_errors = "0"
```

This does not provide automatic rollback of successful executions.

#### Compliance severity

Supported values:

- `UNSPECIFIED`
- `LOW`
- `MEDIUM`
- `HIGH`
- `CRITICAL`

Example:

```hcl
compliance_severity = "MEDIUM"
```

#### Compliance synchronization

Supported values:

- `AUTO`
- `MANUAL`

Example:

```hcl
sync_compliance = "AUTO"
```

#### Wait for success

`wait_for_success_timeout_seconds` optionally configures how long Terraform waits for a successful association execution during resource creation.

Example:

```hcl
wait_for_success_timeout_seconds = 600
```

The value must be a positive integer.

This setting does not guarantee execution ordering between separate associations on future autoscaled instances.

### documents

**Type:** `map(object)`

**Default:** `{}`

Creates custom AWS SSM documents.

AWS-managed documents do not need to be declared here.

#### Document attributes

| Attribute | Type | Required | Default |
|---|---|---|---|
| `name` | string | Yes | — |
| `document_type` | string | Yes | — |
| `content` | string | Yes | — |
| `document_format` | string | No | `"JSON"` |
| `tags` | map(string) | No | `{}` |

Supported document formats:

- `JSON`
- `YAML`

Document types are validated in `variables.tf`.

Common types include:

- `Command`
- `Automation`
- `Policy`
- `Session`
- `Package`

Other supported document types are listed in the module variable validation.

Example:

```hcl
documents = {
  example = {
    name            = "Example-SSM-Document"
    document_type   = "Command"
    document_format = "JSON"

    content = jsonencode({
      schemaVersion = "2.2"
      description   = "Example SSM document"

      mainSteps = [
        {
          action = "aws:runShellScript"
          name   = "example"

          inputs = {
            runCommand = [
              "echo Hello from SSM"
            ]
          }
        }
      ]
    })
  }
}
```

Document content should not contain secrets.

## Outputs

All outputs are maps keyed by the corresponding input identifiers.

| Output | Description |
|---|---|
| `parameter_names` | Parameter names; sensitive output |
| `parameter_arns` | Parameter ARNs |
| `association_ids` | SSM Association IDs |
| `association_names` | Optional association names |
| `document_names` | Custom document names |
| `document_arns` | Custom document ARNs |

The module does not export SSM parameter values.

## Resource behavior

Resources are created with `for_each`.

Changing a map key changes the Terraform resource address and may cause replacement.

Deleting an entry from an input map schedules deletion of the corresponding managed resource on the next apply.

The module does not automatically import or adopt existing AWS resources.

## Execution ordering

SSM associations depend on module-created parameters and documents at the Terraform resource level.

This dependency controls creation ordering, not completion of SSM executions on target instances.

Multiple associations may run independently.

For dependent workflows, such as installing and configuring CloudWatch Agent, use a custom SSM document with ordered steps.

The document should support repeated execution and report failures correctly.

## IAM

IAM permissions are managed by the consuming infrastructure project.

This module does not create IAM roles, policies or instance profiles.

## Security

Terraform state stores SSM parameter values, including SecureString plaintext.

Protect the Terraform state backend, plans and access permissions.

Do not place secrets in parameter names, tags, map keys, association parameters or document content.

## Validation status

Configuration validation completed successfully using:

| OpenTofu | AWS Provider | Result |
|---|---|---|
| 1.12.1 | 5.100.0 | Passed |
| 1.12.1 | 6.70.0 | Passed |

Runtime deployment and execution against AWS Systems Manager have not yet been tested.

## Further information

See the main [README](../README.md) for usage examples, deployment considerations and limitations.
