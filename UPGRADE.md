# Upgrade to the volumes-enabled release

This release adds a new optional `volumes` input and a new optional
`mount_points` field on each `container_definitions` entry. Both
default to a no-op (`{}` / unset), so the upgrade is transparent for
consumers that don't declare volumes — no plan diff, no resource
changes.

When you do start using `volumes`:

- The variable shape is documented in [`docs/volumes.md`](docs/volumes.md),
  including which `type` (`ephemeral` / `efs` / `s3files`) to pick.
- Declaring an EFS or S3 Files volume causes the module to attach a
  least-privilege IAM policy to the task role by default. Set
  `attach_iam_policy = false` per volume to opt out — the computed
  JSON stays exposed as the `volume_iam_policy_json` output.
- EFS IAM authorization defaults to `true` (more secure than the
  AWS provider's default). Explicitly set
  `efs.authorization_config.iam = false` for legacy network-only /
  POSIX-only mounts.
- EFS transit encryption is hard-wired `ENABLED` — there is no
  opt-out, by design for the module's healthcare posture.

# Upgrade from v1.2.1 to v1.2.2

v1.2.2 introduces some changes that allow you to let the module create skeleton IAM roles for your ECS service.

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
