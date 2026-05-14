# Volumes

This module exposes the ECS task-definition `volume` surface as an
opinionated, developer-friendly variable. It supports every volume
type that Fargate on Linux actually supports, and wires the matching
task-role IAM permissions for you by default.

References:

- AWS — [Storage options for Amazon ECS tasks](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_data_volumes.html)
- AWS — [Use Amazon EFS volumes with Amazon ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/efs-volumes.html)
- AWS — [Configuring S3 Files for Amazon ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/s3files-volumes.html)
- AWS — [Fargate task ephemeral storage](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-storage.html)
- Terraform — [`aws_ecs_task_definition` resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition#volume)

## Choosing a volume type

This module's `volumes` variable supports three `type` values:
`ephemeral`, `efs`, and `s3files`. Each maps 1:1 to an underlying AWS
construct.

| Use case | Pick `type =` | Why |
| --- | --- | --- |
| You need scratch space inside the task — e.g. two containers exchanging files via a shared temp directory, or a build artefact that lives only for the lifetime of the task | `ephemeral` | Fargate gives every task 20 GiB of ephemeral storage for free. No external resource to provision, no IAM. Data is gone when the task stops. |
| You need persistent, shared, POSIX-compliant file storage across many tasks — patient-data archives, content-management caches, anything you want to live longer than a single task | `efs` | Amazon EFS is the managed persistent shared-filesystem service. Multiple tasks (and multiple containers within a task) can mount and read/write concurrently. |
| You want to expose an S3 bucket directly as a filesystem to the container — large object access patterns where you don't want to manage a custom Mountpoint-for-S3 entrypoint inside the image | `s3files` | Amazon S3 Files attaches an S3 bucket (via a Mountpoint-for-S3 access point) as a managed mount. Reads/writes go through to S3 transparently. Persistent because S3 is. |

EBS `configure_at_launch`, FSx for Windows, and FSx for NetApp ONTAP
are not in scope for this module — see the *Not supported* section.

### Quick decision shortcuts

- **"I just need a scratch dir between containers in the same task."** → `ephemeral`. Don't reach for EFS.
- **"I need the same data visible to many running tasks at once, and it has to survive the task."** → `efs`.
- **"I already have the data in S3 (or it needs to land in S3) and I want the container to read/write it through a filesystem path."** → `s3files`.
- **"The application needs a block device" / "I need very low-latency single-task block storage."** → EBS `configure_at_launch`. Not supported by this module yet — file an issue if you need it.

## Module surface

`var.volumes` is a `map(object({...}))` keyed by volume name. Each
container that wants to use a volume references it by name via
`container_definitions[*].mount_points[*].sourceVolume`. The names you
use here are the same names referenced in `mountPoints`.

```hcl
module "service" {
  source = "github.com/Luscii/terraform-aws-ecs-service?ref=<version>"

  # ... usual inputs (name, context, vpc_id, subnets, cluster, cpu, memory)

  volumes = {
    # See type-specific sections below
  }

  container_definitions = [
    {
      name  = "app"
      image = "..."
      mount_points = [
        { sourceVolume = "scratch", containerPath = "/tmp/work" },
      ]
    }
  ]
}
```

A `sourceVolume` that does not match a declared `var.volumes` key
fails plan with a clear precondition error — no silent typos.

## `type = "ephemeral"` — Fargate scratch

```hcl
volumes = {
  scratch = { type = "ephemeral" }
}
```

That is the entire configuration. Backed by Fargate's built-in
20 GiB ephemeral storage (or whatever you raise it to via
`ephemeralStorage` on the task definition, up to 200 GiB).

- **Persistent?** No. Data is gone when the task stops.
- **Shared?** Across containers *within the same task*, yes. Across tasks, no.
- **IAM?** None needed. `attach_iam_policy` is a no-op for ephemeral volumes.

Best used for inter-container file passing in a single task. If you
catch yourself reaching for ephemeral to share data *between* tasks,
you actually want `efs` instead.

## `type = "efs"` — Amazon EFS

```hcl
volumes = {
  patient_data = {
    type = "efs"
    efs = {
      file_system_id = aws_efs_file_system.patient_data.id
      authorization_config = {
        access_point_id = aws_efs_access_point.patient_data.id
      }
    }
  }
}
```

### Prerequisites the module does NOT manage

Provision these in your own `infrastructure/` Terraform:

1. An `aws_efs_file_system`.
2. `aws_efs_mount_target` in each subnet your tasks run in — the EFS
   client mounts via NFS/2049 to the mount target.
3. A security group on the mount target that allows TCP/2049 *from
   the service's security group*. The module's `aws_security_group`
   output is at `module.<name>.security_group_id`.
4. (Recommended) An `aws_efs_access_point` per logical scope. The
   access point owns the POSIX uid/gid the mount sees and pins the
   root directory subtree.

### Configuration fields

`file_system_id` is required. Everything else has a defaulted, secure
choice.

| Field | Default | Notes |
| --- | --- | --- |
| `file_system_id` | (required) | The EFS file system ID, e.g. `fs-0a1b2c3d`. The module composes the ARN. |
| `root_directory` | AWS default (`/`) | A subdirectory to expose as the mount root. **Must be omitted or `/` when `authorization_config.access_point_id` is set** — access points root the mount themselves, and ECS rejects any other combination at task definition registration. The module validates this at plan time. |
| `transit_encryption_port` | AWS-chosen | The port for the encrypted NFS channel. AWS picks one if omitted. Transit encryption itself is always `ENABLED` on the rendered volume — the module does not expose an opt-out. |
| `kms_key_arn` | `null` | Set when the file system is encrypted with a customer-managed KMS key. The module uses this ARN to scope the auto-attached KMS statements. |
| `authorization_config.access_point_id` | `null` | The EFS access point to mount through. Strongly recommended for any multi-tenant or compliance-sensitive use. |
| `authorization_config.iam` | **`true`** | EFS IAM authorization. **More secure than the AWS provider's default**, which is off. Set `false` for legacy mounts that rely on security groups + POSIX only. |

### `iam = true` vs `iam = false`

EFS has two independent access-control layers:

1. **Network** — security group on the mount target allows port 2049 from the task SG. Always required.
2. **Filesystem** — either POSIX permissions (the AWS default), or IAM authorization, or both.

When `iam = true` (the module's default), ECS uses the task role's
IAM credentials to authenticate at mount time. The task role must
have `elasticfilesystem:ClientMount` (+`ClientWrite`/`ClientRootAccess`
for writers) on the file system ARN. The module attaches the matching
statements automatically — see *IAM auto-attach* below.

When `iam = false`, network connectivity + POSIX is the only barrier.
A misconfigured SG that allows port 2049 from somewhere unintended is
enough to expose the filesystem. Defensible only for legacy mounts.

## `type = "s3files"` — Amazon S3 Files

```hcl
volumes = {
  mesh = {
    type = "s3files"
    s3files = {
      access_point_arn = aws_s3control_multi_region_access_point.mesh.alias  # or a regional Mountpoint-for-S3 access point ARN
      file_system_arn  = aws_s3files_file_system.mesh.arn
      kms_key_arn      = aws_kms_key.mesh.arn
    }
  }
}
```

### Prerequisites the module does NOT manage

1. An `aws_s3_bucket` to back the file system.
2. An S3 Files file system (`AWS::S3Files::FileSystem` /
   `aws_s3files_file_system`) wired to the bucket, plus its service
   role.
3. A Mountpoint-for-S3 access point that scopes the bucket prefix the
   task sees.
4. KMS key + key policy when SSE-KMS is in use — S3 Files
   provisioning via Terraform / CFN currently *requires* SSE-KMS, so
   in practice you always have a KMS key here.
5. VPC + subnet reachability to the S3 Files mount target.

### Configuration fields

`access_point_arn` and `file_system_arn` are both required by AWS;
the module mirrors that.

| Field | Default | Notes |
| --- | --- | --- |
| `access_point_arn` | (required) | The Mountpoint-for-S3 access point ARN. Scopes the bucket prefix the task sees. |
| `file_system_arn` | (required) | The S3 Files file system ARN, format `arn:<partition>:s3files:<region>:<account>:file-system/fs-xxxxx`. |
| `root_directory` | AWS default (`/`) | Subdirectory of the access point's scoped prefix to expose as the mount root. |
| `transit_encryption_port` | AWS-chosen | Encrypted channel port. Transit encryption itself is *always on* — AWS enforces it, there is no opt-out. |
| `kms_key_arn` | `null` | Set when the backing bucket is encrypted with a customer-managed KMS key. Used to scope the auto-attached KMS statements. |

### Why no `transit_encryption` bool?

Because AWS doesn't let you turn it off. S3 Files mounts are always
TLS. Same goes for the task role being mandatory — see the
*IAM auto-attach* section.

## Mount points on containers

Each container that wants access to a declared volume references it
by name:

```hcl
container_definitions = [
  {
    name  = "app"
    image = "..."
    mount_points = [
      { sourceVolume = "patient_data", containerPath = "/var/data" },
      { sourceVolume = "scratch",      containerPath = "/tmp/work", readOnly = true },
    ]
  },
  {
    name  = "sidecar"
    image = "..."
    mount_points = [
      { sourceVolume = "patient_data", containerPath = "/mnt/shared", readOnly = true },
    ]
  },
]
```

Fields are the camelCase shape the rest of `container_definitions`
already uses (matching the underlying cloudposse sub-module and the
raw ECS task-definition JSON).

A `sourceVolume` that doesn't match a declared `var.volumes` key
fails plan with a precondition error listing the volumes that *are*
declared.

### Read/write derivation

The module aggregates `readOnly` across every mount of a given
volume to decide what to grant in IAM. A volume is treated as RW if
*any* container's mount of it has `readOnly = false` (the default).
Read-only volumes get only the read-side actions; mixing RW and RO
mounts of the same volume falls back to RW grants.

## IAM auto-attach

By default (`attach_iam_policy = true`), the module computes a
least-privilege IAM policy from your declared volumes and attaches
it inline to the task role as `aws_iam_role_policy.task_volumes`.

What the module grants:

| Volume shape | Actions | Resource | Condition |
| --- | --- | --- | --- |
| `ephemeral` | (none) | — | — |
| `efs` with `iam = false` | (none) | — | — |
| `efs` with `iam = true`, read-only | `elasticfilesystem:ClientMount` | `arn:aws:elasticfilesystem:<region>:<account>:file-system/<file_system_id>` | `StringEquals` on `elasticfilesystem:AccessPointArn` when `access_point_id` is set |
| `efs` with `iam = true`, RW, with access point | `ClientMount`, `ClientWrite` | file-system ARN | `AccessPointArn` condition (access point already roots the scope, so `ClientRootAccess` is omitted) |
| `efs` with `iam = true`, RW, no access point | `ClientMount`, `ClientWrite`, `ClientRootAccess` | file-system ARN | — |
| `s3files`, read-only | `s3:ListBucket` | the `access_point_arn` | — |
| `s3files`, read-only | `s3:GetObject` | `${access_point_arn}/object/*` | — |
| `s3files`, RW | `s3:ListBucket` | the `access_point_arn` | — |
| `s3files`, RW | `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` | `${access_point_arn}/object/*` | — |
| Any with `kms_key_arn` set, read-only | `kms:Decrypt` | the `kms_key_arn` | — |
| Any with `kms_key_arn` set, RW | `kms:Decrypt`, `kms:Encrypt`, `kms:GenerateDataKey` | the `kms_key_arn` | — |

All statements land in one inline policy attached to the task role —
the role the module creates *or* the role you brought via
`var.task_role`.

### Opting out

Set `attach_iam_policy = false` per volume to suppress the inline
policy *for that volume*. The module still renders the volume block
on the task definition; it just doesn't attach IAM. The computed
policy JSON stays available as `module.<name>.volume_iam_policy_json`
so you can attach it (or a modified version) yourself:

```hcl
resource "aws_iam_role_policy" "volumes" {
  count  = var.task_role == null ? 1 : 0
  name   = "my-service-volumes"
  role   = module.service.service_task_role_name
  policy = module.service.volume_iam_policy_json
}
```

Use the opt-out when:

- You need read-only scoping the module's RW-derivation didn't catch
  (e.g. you want IAM read-only even though one mount happens to have
  `readOnly = false`).
- You need to add `Condition` keys the module doesn't compute
  (`aws:SourceIp`, `aws:SecureTransport`, etc.).
- Your task role lives outside this Terraform tree entirely and the
  policy is managed elsewhere.

### KMS specifics

The module does not data-source the KMS key for you — that would
require the bucket / file system to exist at plan time, which breaks
greenfield setups (where the bucket and the service are created in
the same plan). Pass `kms_key_arn` explicitly. Leave it `null` when
the backing storage is encrypted with SSE-S3 / EFS-default
encryption.

The AWS-managed keys `aws/s3` and `aws/elasticfilesystem` count as
KMS keys — pass their ARN if your bucket / file system points at
them. The IAM model treats them the same as customer-managed CMKs.

## Not supported

The module exposes only volume types that Fargate on Linux supports.
The following are excluded by design:

- **EBS `configure_at_launch`.** Supported by Fargate, but requires
  a paired service-level `volume_configuration` block to provision
  the EBS volume at task launch. Deferred until a real consumer asks
  — file an issue.
- **FSx for Windows File Server.** Amazon EC2 launch type only.
- **FSx for NetApp ONTAP.** Amazon EC2 launch type only.
- **Docker volumes.** Amazon EC2 launch type only.
- **Bind mounts to host paths.** Fargate has no host filesystem
  to bind to; "ephemeral" above is the only bind-mount-equivalent
  the platform offers.
