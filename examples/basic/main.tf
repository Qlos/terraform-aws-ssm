module "ssm" {
  source = "../.."

  tags = { ManagedBy = "Terraform" }

  parameters = {
    settings = {
      name  = "/example/service/settings"
      value = jsonencode({ enabled = true })
    }
  }

  associations = {
    package = {
      name             = "AWS-ConfigureAWSPackage"
      association_name = "example-install-agent"
      parameters = {
        action = "Install"
        name   = "AmazonCloudWatchAgent"
      }
      targets = [{ key = "tag:Monitoring", values = ["enabled"] }]
    }
  }
}
