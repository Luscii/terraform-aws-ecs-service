# Volumes Reference

Volumes for the ECS task definition, plus the per-container
`mount_points` that consume them. Configures every volume type that
Fargate on Linux supports today: ephemeral (in-task scratch), EFS,
and S3 Files.

For the decision guide ("which type for which job?") and the per-type
prose walkthrough, see [../../docs/volumes.md](../../docs/volumes.md).

## Table of Contents

- [Schema Overview](#schema-overview)
- [Type Discriminator](#type-discriminator)
- [Ephemeral Volumes](#ephemeral-volumes)
- [EFS Volumes](#efs-volumes)
- [S3 Files Volumes](#s3-files-volumes)
- [Mount Points on Containers](#mount-points-on-containers)
- [IAM Auto-Attach Behaviour](#iam-auto-attach-behaviour)
- [Validation](#validation)

## Schema Overview

```hcl
volumes = map(object({
  type              = string                    # "ephemeral" | "efs" | "s3files"
  attach_iam_policy = optional(bool, true)      # opt out per-volume

  efs = optional(object({
    file_system_id          = string
    root_directory          = optional(string)
    transit_encryption_port = optional(number)
    kms_key_arn             = optional(string)
    authorization_config = optional(object({
      access_point_id = optional(string)
      iam             = optional(bool, true)    # secure-by-default
    }), {})
  }))

  s3files = optional(object({
    access_point_arn        = string
    file_system_arn         = string
    root_directory          = optional(string)
    transit_encryption_port = optional(number)
    kms_key_arn             = optional(string)
  }))
}))
```

Default is `{}` — no volumes declared, zero plan diff for existing
consumers.

## Type Discriminator

| `type` | Use case | Persistent? | Sub-block required |
|--------|----------|-------------|--------------------|
| `ephemeral` | Scratch space shared between containers in the same task | No | None |
| `efs` | Persistent, shared, POSIX file storage across tasks | Yes | `efs` |
| `s3files` | Mount an S3 bucket as a filesystem (via a Mountpoint-for-S3 access point) | Yes (S3) | `s3files` |

Out of scope by design: EBS `configure_at_launch`, FSx for Windows /
NetApp ONTAP, Docker volumes, host bind mounts. None work on Fargate
Linux without paired service-level orchestration the module doesn't
provide today.

## Ephemeral Volumes

```hcl
volumes = {
  scratch = { type = "ephemeral" }
}
```

The whole configuration. Backed by Fargate's built-in ephemeral
storage (20 GiB free per task, up to 200 GiB via `ephemeralStorage`
on the task definition). Shared across containers *within the same
task*. No IAM, no networking.

## EFS Volumes

```hcl
volumes = {
  patient_data = {
    type = "efs"
    efs = {
      file_system_id = aws_efs_file_system.patient.id
      authorization_config = {
        access_point_id = aws_efs_access_point.patient.id
      }
    }
  }
}
```

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `file_system_id` | `string` | *required* | EFS file system ID (e.g. `fs-0a1b2c3d`). The module composes the ARN. |
| `root_directory` | `string` | AWS default (`/`) | Subdirectory to expose as the mount root. **Must be omitted or `/` when `authorization_config.access_point_id` is set** — access points root the mount themselves; ECS rejects any other combo. Module validates this at plan time. |
| `transit_encryption_port` | `number` | AWS-chosen | Custom port for the encrypted NFS channel. Transit encryption itself is hard-wired `ENABLED` — no opt-out, by design. |
| `kms_key_arn` | `string` | `null` | Set when the file system is encrypted with a customer-managed KMS key. Scopes the auto-attached KMS statements. |
| `authorization_config.access_point_id` | `string` | `null` | EFS access point ID to mount through. Strongly recommended for multi-tenant / compliance-sensitive workloads. |
| `authorization_config.iam` | `bool` | `true` | EFS IAM authorization. **More secure than the AWS provider default.** Set `false` for legacy POSIX-only mounts. |

**EFS prerequisites the module does NOT manage:**

- `aws_efs_file_system` itself
- `aws_efs_mount_target` in each subnet your tasks run in
- Security group on the mount target allowing TCP/2049 from
  `module.<name>.security_group_id`
- (Recommended) `aws_efs_access_point` per logical scope

## S3 Files Volumes

```hcl
volumes = {
  mesh = {
    type = "s3files"
    s3files = {
      access_point_arn = aws_s3control_access_point.mesh.arn
      file_system_arn  = aws_s3files_file_system.mesh.arn
      kms_key_arn      = aws_kms_key.mesh.arn
    }
  }
}
```

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `access_point_arn` | `string` | *required* | Mountpoint-for-S3 access point ARN. Scopes the bucket prefix the task sees. |
| `file_system_arn` | `string` | *required* | S3 Files file system ARN: `arn:<partition>:s3files:<region>:<account>:file-system/fs-xxxxx`. |
| `root_directory` | `string` | AWS default (`/`) | Subdirectory of the access point's scoped prefix to expose as the mount root. |
| `transit_encryption_port` | `number` | AWS-chosen | Encrypted channel port. Transit encryption itself is *always on* — AWS enforces it, no opt-out. |
| `kms_key_arn` | `string` | `null` | Set when the backing bucket is CMK-encrypted (typical for S3 Files since IaC provisioning requires SSE-KMS). |

**S3 Files prerequisites the module does NOT manage:**

- The S3 bucket and its policy
- The S3 Files file system + its service role
- The Mountpoint-for-S3 access point
- The KMS key + key policy when SSE-KMS is in use

## Mount Points on Containers

Each container references declared volumes by name via the new
`mount_points` field on `container_definitions`:

```hcl
container_definitions = [
  {
    name  = "app"
    image = "..."
    mount_points = [
      { sourceVolume = "patient_data", containerPath = "/var/data" },
      { sourceVolume = "scratch",      containerPath = "/tmp/work", readOnly = true },
    ]
  }
]
```

Camel-case keys to match the rest of the ECS-JSON container surface
(`port_mappings`, `log_configuration`).

A `sourceVolume` that doesn't match a declared `var.volumes` key
fails plan at `aws_ecs_task_definition.this`'s precondition with a
clear error listing the volumes that *are* declared.

### Read/write aggregation

The module unions `readOnly` across every mount of a given volume to
decide what to grant in IAM. A volume is treated as RW if *any*
container's mount of it has `readOnly = false` (the default).
Read-only volumes get only read-side actions.

## IAM Auto-Attach Behaviour

By default (`attach_iam_policy = true`), the module computes a
least-privilege inline policy from the declared volumes and attaches
it to the task role as `aws_iam_role_policy.task_volumes` — created
when at least one volume contributes statements, omitted otherwise.

| Volume shape | Actions granted | Resource | Condition |
|--------------|-----------------|----------|-----------|
| `ephemeral` | (none) | — | — |
| `efs`, `iam = false` | (none) | — | — |
| `efs`, `iam = true`, RO | `elasticfilesystem:ClientMount` | file-system ARN | `AccessPointArn` when set |
| `efs`, `iam = true`, RW, with access point | `+ClientWrite` | file-system ARN | `AccessPointArn` |
| `efs`, `iam = true`, RW, no access point | `+ClientWrite`, `+ClientRootAccess` | file-system ARN | — |
| `s3files`, RO | `s3:ListBucket` | access point ARN | — |
| `s3files`, RO | `s3:GetObject` | `${access_point_arn}/object/*` | — |
| `s3files`, RW | `s3:ListBucket` | access point ARN | — |
| `s3files`, RW | `s3:GetObject`, `+s3:PutObject`, `+s3:DeleteObject` | `${access_point_arn}/object/*` | — |
| Any with `kms_key_arn`, RO | `kms:Decrypt` | KMS key ARN | — |
| Any with `kms_key_arn`, RW | `+kms:Encrypt`, `+kms:GenerateDataKey` | KMS key ARN | — |

The policy attaches to the role this module creates *or* the role
the consumer brought via `var.task_role`. The computed JSON is also
exposed as `module.<name>.volume_iam_policy_json` for opt-out
consumers.

### Opting out per volume

```hcl
volumes = {
  data = {
    type              = "efs"
    attach_iam_policy = false             # suppresses inline policy for this volume
    efs               = { file_system_id = aws_efs_file_system.data.id }
  }
}

resource "aws_iam_role_policy" "data_volumes" {
  # Null when no volume contributes IAM (ephemeral-only or
  # EFS-without-IAM-auth). Works for module-created and bring-your-own
  # task roles alike — `service_task_role_name` resolves to whichever
  # is in use.
  count = module.my_service.volume_iam_policy_json != null ? 1 : 0

  name   = "my-service-data-volumes"
  role   = module.my_service.service_task_role_name
  policy = module.my_service.volume_iam_policy_json    # the full JSON the module computed
}
```

Use the opt-out when you need stricter scoping than the module
computes (extra `Condition` keys, read-only enforcement the
RW-derivation didn't catch, or task roles managed elsewhere).

## Validation

The module enforces four checks at plan time:

1. **`type` value** — must be one of `ephemeral`, `efs`, `s3files`. Invalid values fail `var.volumes` validation with the allowed-set listed.
2. **Type / sub-block match** — `ephemeral` rejects any `efs` or `s3files` block; `efs` requires only `efs`; `s3files` requires only `s3files`. Mixed configurations fail `var.volumes` validation.
3. **EFS access point ↔ `root_directory`** — when `efs.authorization_config.access_point_id` is set, `efs.root_directory` must be omitted or `/`. ECS rejects any other combo at task definition registration; this rule catches it at plan time.
4. **`sourceVolume` references a declared volume** — every container's `mount_points[*].sourceVolume` must match a key in `var.volumes`. Cross-variable check; lives as a precondition on `aws_ecs_task_definition.this` (variable validation can't see other variables). Failure lists the declared volumes for quick fix.

## Requirements

- AWS Provider **>= 6.41.0** — required by `volume.s3files_volume_configuration` on `aws_ecs_task_definition`.
