# Upgrade from v1.2.1 to v1.3.0

v1.3.0 introduces some changes that allow you to let the module create skeleton IAM roles for your ECS service.

This document highlights common/known steps, but always verify your Terraform plan output.
More or different steps may be needed for your setup to upgrade successfully.

Ultimately, we **do not want to destroy anything by upgrading**, merely move/replace things.
Keep this in mind when looking at your plan. Nothing should be removed permanently.

## IAM Roles

**Scenario: MIGRATE IAM ROLES**

The task role and execution role for the ECS service are now included in the module.
You can move any existing ones you may have in your project:

```bash
terraform state mv aws_iam_role.execution 'module.<LABEL USED FOR THE ECS MODULE>.aws_iam_role.execution[0]'
terraform state mv aws_iam_role.task 'module.<LABEL USED FOR THE ECS MODULE>.aws_iam_role.task[0]'
```

You must also remove the `task_role` and `execution_role` variables from the module configuration, so the module knows it will now be in charge of managing these.
Keeping these variables set will act as backwards compatible setup, where your project has to create the roles and policies.

**Scenario: KEEP EXISTING IAM ROLES**

If you want to keep your existing IAM roles, you do not have to do anything.
Keeping the `task_role` and `execution_role` variables set will result in backwards compatibility.
No new roles will be created and the policies of existing roles will remain unchanged.

**Please note:** You can safely move the roles to the module, but attach additional policies to it, if your project needs more than "default" access.
The module now exports the `service_task_role_arn` and `service_execution_role_arn` outputs to be used in your project to attach additional policies to them.
Please consider this, instead of keeping your legacy roles.
