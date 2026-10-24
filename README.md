
# terraform-aws-ssm

Reusable Terraform module for AWS Systems Manager (SSM).

Developed by the DevOps Team at [Qlos](https://qlos.com).

## About

This module supports:

- SSM Parameter Store parameters
- SSM State Manager associations
- Custom SSM documents

Resources are managed using maps and `for_each`, allowing multiple resources to be created from a single module invocation.

All resource collections are optional and default to empty.

The module does not create IAM roles, EC2 instances, ECS services, CloudWatch dashboards or alarms.

## Requirements

- Terraform >= 1.3.0 or compatible OpenTofu
- AWS provider >= 5.0

### Tested compatibility

Configuration validation completed successfully with:

| Component | Version | Result |
|---|---|---|
| OpenTofu | 1.12.1 | Passed |
| AWS Provider | 5.100.0 | Passed |
| AWS Provider | 6.70.0 | Passed |

The initial consuming project, BridgeSolutionsHub, uses:

- OpenTofu 1.10.6
- Terragrunt 0.91.4
- AWS Provider 5.x

Runtime testing against AWS Systems Manager has not yet been performed. Compatibility with OpenTofu 1.10.6 has not been independently validated.

## Usage

### Parameters

Create a simple SSM Parameter Store parameter:

```hcl
module "ssm" {
  source = "github.com/Qlos/terraform-aws-ssm?ref=v1.0.0"

  parameters = {
    application_config = {
      name        = "/example/prod/config"
      value       = jsonencode({ enabled = true })
      description = "Application configuration"
    }
  }

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
```

Only `name` and `value` are required for each parameter.

Default values:

- `type = "String"`
- `tier = "Standard"`
- `description = null`
- `key_id = null`
- `tags = {}`

Multiple parameters can be created in one module invocation.

### SecureString parameters

```hcl
parameters = {
  api_secret = {
    name  = "/example/prod/api-secret"
    type  = "SecureString"
    value = var.api_secret
  }
}
```

**Important:** Terraform state stores parameter values, including SecureString values. Protect the state backend and avoid hardcoding secrets in source code.

### State Manager associations

Create an association targeting EC2 instances by tag:

```hcl
module "ssm" {
  source = "github.com/Qlos/terraform-aws-ssm?ref=v1.0.0"

  associations = {
    package_install = {
      name             = "AWS-ConfigureAWSPackage"
      association_name = "example-package-install"

      parameters = {
        action = "Install"
        name   = "AmazonCloudWatchAgent"
      }

      targets = [
        {
          key    = "tag:Name"
          values = ["example-ecs-worker"]
        }
      ]

      max_concurrency     = "1"
      max_errors          = "0"
      compliance_severity = "MEDIUM"
      sync_compliance     = "AUTO"
    }
  }
}
```

This example installs CloudWatch Agent but does not configure or start metric collection.

Target instances must be registered and managed by AWS Systems Manager.

### Custom SSM documents

```hcl
module "ssm" {
  source = "github.com/Qlos/terraform-aws-ssm?ref=v1.0.0"

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
                "echo SSM document executed"
              ]
            }
          }
        ]
      })
    }
  }
}
```

AWS-managed SSM documents do not need to be created through this module.

Custom documents can be combined with State Manager associations to implement ordered, multi-step workflows.

## State Manager association options

| Input | Description | Default |
|---|---|---|
| `name` | SSM document name | Required |
| `association_name` | Friendly association name | `null` |
| `document_version` | SSM document version | `null` |
| `parameters` | Document-specific parameters | `{}` |
| `targets` | EC2 instance tag targets | Required |
| `schedule_expression` | Cron or rate expression | `null` |
| `apply_only_at_cron_interval` | Execute only at cron interval | `false` |
| `max_concurrency` | Maximum concurrent targets | AWS default |
| `max_errors` | Error threshold | AWS default |
| `compliance_severity` | Compliance severity | `UNSPECIFIED` |
| `sync_compliance` | Compliance reporting mode | `AUTO` |
| `wait_for_success_timeout_seconds` | Optional wait for successful execution | `null` |

### Recommended production settings

For a small production ECS worker fleet:

```hcl
max_concurrency     = "1"
max_errors          = "0"
compliance_severity = "MEDIUM"
sync_compliance     = "AUTO"
```

These settings are recommendations, not enforced module defaults.

`max_concurrency = "1"` limits association execution concurrency to one target at a time.

`max_errors = "0"` configures the error threshold. It does not roll back changes already completed on other instances.

## Execution ordering

Terraform resource dependencies control resource creation order.

They do not guarantee that an SSM association has successfully executed on every target instance.

Two separate associations, such as one installing CloudWatch Agent and another configuring it, may execute in the wrong order.

This can happen during initial deployment and when new instances join an Auto Scaling Group.

For workflows involving dependent operations, use a single custom SSM document with ordered steps.

For example:

1. Install CloudWatch Agent.
2. Load its configuration from Parameter Store.
3. Start or restart the agent.
4. Verify the result.

Such a document should handle failures properly and support repeated execution.

Associations targeting EC2 tags can automatically apply to current and future matching managed nodes.

## IAM permissions

This module does not manage IAM permissions.

Managed EC2 instances require:

- A working SSM Agent
- Connectivity to AWS Systems Manager
- Appropriate IAM permissions for Systems Manager
- Permissions required by the executed document

CloudWatch Agent additionally requires permissions to publish metrics to CloudWatch and read its configuration.

IAM permissions should be managed by the consuming project.

## Parameter Store security

Terraform state stores SSM parameter values.

This includes values with type `SecureString`.

SecureString protects the value in AWS using KMS encryption but does not prevent the plaintext value from appearing in Terraform state.

Protect Terraform state, plans and backend access.

The `parameters` input is marked sensitive.

Parameter values are not exposed through module outputs.

Do not put secrets in parameter names, tags, map keys, association parameters or custom document content.

## Outputs

| Output | Description |
|---|---|
| `parameter_names` | Parameter names keyed by input identifier |
| `parameter_arns` | Parameter ARNs keyed by input identifier |
| `association_ids` | Association IDs keyed by input identifier |
| `association_names` | Association names keyed by input identifier |
| `document_names` | Custom document names keyed by input identifier |
| `document_arns` | Custom document ARNs keyed by input identifier |

Outputs use the same map keys as their corresponding inputs.

No parameter values are exported.

## Compatibility

The module requires AWS Provider >= 5.0.

The actual provider version should be constrained by the consuming project.

For example, BridgeSolutionsHub uses:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

This limits the consuming project to AWS Provider 5.x.

## Limitations

- Does not guarantee execution ordering between separate associations.
- Does not create IAM roles or EC2 instance profiles.
- Does not configure CloudWatch dashboards or alarms.
- Does not delete historical CloudWatch metrics after EC2 termination.
- Does not automatically install CloudWatch Agent without a suitable association.
- Does not manage CloudWatch Logs retention.
- Does not provide built-in rollback of SSM document executions.

## Validation

The module has passed configuration validation using OpenTofu 1.12.1 with AWS providers 5.100.0 and 6.70.0.

To validate locally:

```bash
tofu fmt -check -recursive
tofu init -backend=false
tofu validate
```

When testing a different provider version, update the version constraint and run:

```bash
tofu init -backend=false -upgrade
tofu validate
```

Validation checks Terraform configuration and provider schema compatibility. It does not guarantee successful execution against AWS.

Review the plan in the consuming environment before deployment.

## Documentation

See [docs/terraform.md](docs/terraform.md) for the complete module interface.

## License

MIT. See [LICENSE](LICENSE).
