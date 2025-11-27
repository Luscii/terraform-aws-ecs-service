# Upgrade from v1.2.1 to v2.0.0

v2.0.0 introduces some backwards incompatible changes that require your attention.

This document highlights common/known steps, but always verify your Terraform plan output. More or different steps may be needed for your setup to upgrade successfully.

Ultimately, we **do not want to destroy anything by upgrading**, merely move/replace things. Keep this in mind when looking at your plan. Nothing should be removed permanently.

## CloudWatch Log Group

**Scenario: MIGRATE LOG GROUP**

The CloudWatch Log Group for the ECS service is now included in the module. You can move the existing one:

```bash
terraform state mv aws_cloudwatch_log_group.log 'module.<LABEL USED FOR THE ECS MODULE>.aws_cloudwatch_log_group.this[0]'
```

This resource does require you to specify how many days you want to keep the logs, by setting the new `log_retention_in_days` variable.

**Scenario: KEEP EXISTING LOG GROUP**

If you prefer to keep using your existing (customized) log group, you must then pass its ARN with the `cloudwatch_log_group_arn` variable, like so:

```hcl
module "ecs_service" {
    // ... existing configuration
    cloudwatch_log_group_arn = "<YOUR LOG GROUP ARN>"
}
```

## IAM Roles

**Scenario: MIGRATE IAM ROLES**

The task role and execution role for the ECS service are now included in the module. You can move the existing ones:

```bash
terraform state mv aws_iam_role.execution 'module.<LABEL USED FOR THE ECS MODULE>.aws_iam_role.execution_role[0]'
terraform state mv aws_iam_role_policy.execution 'module.<LABEL USED FOR THE ECS MODULE>.aws_iam_role_policy.execution_role[0]'
terraform state mv aws_iam_role.task 'module.<LABEL USED FOR THE ECS MODULE>.aws_iam_role.task_role[0]'
```

You must also remove the `task_role` and `execution_role` variables from the module configuration, so the module knows it will now be in charge of managing these. Keeping these variables set will act as backwards compatible setup, where your project has to create the roles and policies.

If your project uses the secrets module, you will have to make sure that the new roles can access those secrets. By setting the `secrets_arns` and `secrets_kms_key_arn` variables, the module will now make sure the the execution role can read those secrets and decrypt them with the KMS key provided. The Secrets module exports an output for both those values, so you should be able to pass them directly from there, like so:

```hcl
module "ecs_service" {
  // ... existing configuration
  secrets_arns        = module.secrets.arns
  secrets_kms_key_arn = module.secrets.kms_key_arn
}
```

**Scenario: KEEP EXISTING IAM ROLES**

If you want to keep your existing IAM roles, you do not have to do anything. Keeping the `task_role` and `execution_role` variables set will result in backwards compatibility. No new roles will be created and the policies of existing roles will remain unchanged.

**Please note:** You can safely move the roles to the module, but attach additional policies to it, if your project needs more than "default" access. The module now exports the `service_task_role_arn` and `service_execution_role_arn` outputs to be used in your project to attach additional policies to them. Please consider this, instead of keeping your legacy roles.
