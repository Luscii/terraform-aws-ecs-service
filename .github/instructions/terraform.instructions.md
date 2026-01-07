---
applyTo: "**/*.tf"
---

# Terraform Module Development Instructions

## Quick Reference

**When writing Terraform code:**
- Use 2-space indentation, align `=` signs
- Variables and outputs in alphabetical order (`context` first)
- Use CloudPosse label module (v0.25.0) for naming/tagging
- Add descriptions to all variables and outputs
- Validate inputs with validation blocks
- Split large files by function (network.tf, security.tf, etc.)
- Use `this` for primary resources
- Run: `terraform fmt`, `terraform validate`, security scans

**Cross-references:**
- Variable/output descriptions → [documentation.instructions.md](./documentation.instructions.md)
- Examples → [examples.instructions.md](./examples.instructions.md)

---

## Required File Structure

Every module **must** include these files (even if empty):

| File | Purpose | Required |
|------|---------|----------|
| `main.tf` | Primary resource and data source definitions | ✅ Yes |
| `variables.tf` | Input variable definitions (alphabetical order) | ✅ Yes |
| `outputs.tf` | Output value definitions (alphabetical order) | ✅ Yes |
| `README.md` | Module documentation (root module only) | ✅ Yes |
| `versions.tf` | Version constraints for Terraform and providers | ✅ Yes |
| `LICENSE` | License information | Especially for public modules |

**Additional Optional Files:**
- `locals.tf` - Local value definitions (when complex)
- `backend.tf` - Backend configuration (for root modules)
- `{resource-type}.tf` - Resource-specific files (e.g., `security-group.tf`, `iam-role-policies.tf`)

## File Organization

### Standard File Structure
Organize Terraform code into separate files based on functionality:

- **main.tf**: Data sources, module label/context initialization, and central locals
- **variables.tf**: All input variable declarations
- **outputs.tf**: All output declarations
- **versions.tf**: Terraform and provider version constraints
- **{resource-type}.tf**: Resource-specific files (e.g., `security-group.tf`, `iam-role-policies.tf`, `scaling.tf`)

### File Naming Conventions
- Use kebab-case for file names (e.g., `ecs-service.tf`, `access-logs.tf`)
- Create separate files for logically grouped resources
- Name files after the primary resource or functionality they contain

### Directory Structure

**Standard Module Layout:**
```
terraform-<PROVIDER>-<NAME>/
├── README.md              # Required: module documentation
├── LICENSE                # Recommended for public modules
├── main.tf                # Required: primary resources
├── variables.tf           # Required: input variables (alphabetical)
├── outputs.tf             # Required: output values (alphabetical)
├── versions.tf            # Required: version constraints
├── backend.tf             # Root modules: backend config
├── locals.tf              # Optional: local values
├── {resource-type}.tf     # Optional: resource-specific files
├── modules/               # Nested modules directory
│   ├── submodule-a/
│   │   ├── README.md      # Include if externally usable
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── submodule-b/
│       ├── main.tf        # No README = internal only
│       ├── variables.tf
│       └── outputs.tf
├── examples/              # Usage examples directory
│   ├── README.md
│   ├── basic/
│   │   ├── README.md
│   │   └── main.tf        # Use external source, not relative
│   └── advanced/
│       ├── README.md
│       └── main.tf
└── tests/                 # Tests directory
    └── <TEST_NAME>.tftest.tf
```

**Key Principles:**
- **Module repos:** `terraform-<PROVIDER>-<NAME>` (e.g., `terraform-aws-vpc`)
- **Local modules:** `./modules/<module_name>`
- **Nested modules with README.md:** Public-facing, can be used independently
- **Nested modules without README.md:** Internal-only implementation details
- **Examples:** Demonstrate usage with external source references
- **Tests:** Terraform native tests using `.tftest.tf` files

### Code Organization

**File Splitting by Function:**

Split large configurations into logical files:
- `network.tf` - Networking resources (VPCs, subnets, route tables)
- `compute.tf` - Compute resources (EC2, ECS, Lambda)
- `storage.tf` - Storage resources (S3, EBS, EFS)
- `security.tf` or `security-group.tf` - Security resources
- `iam-role-policies.tf` - IAM roles and policies
- `monitoring.tf` - CloudWatch, logging, alarms
- `scaling.tf` - Auto-scaling configurations

**Naming Principles:**
- Use descriptive resource names reflecting their purpose
- Keep modules focused on single infrastructure concerns
- Use `this` for primary/single resources
- Use descriptive names for multiple related resources

## Module Structure Patterns

### Label/Context Module Usage

**Required:** Always use the CloudPosse label module (v0.25.0) for consistent resource naming and tagging.

```terraform
module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context = var.context
  name    = var.name
  # Optional: attributes, id_length_limit, etc.
}
```

**Usage:**
- `module.label.id` → for resource names
- `module.label.tags` → for resource tags
- `module.label.context` → for passing to nested modules

**Special Cases:**
- Set `id_length_limit` when resources have name length constraints (e.g., ALB: 32 chars)
- Create additional label modules for sub-resources needing distinct names

### Data Source Patterns
Place data sources at the top of **main.tf**:

```terraform
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
```

## Variables

### Standard Context Variable
Always include the standard context variable as the first variable:

```terraform
variable "context" {
  type = any
  default = {
    enabled             = true
    namespace           = null
    tenant              = null
    environment         = null
    stage               = null
    name                = null
    delimiter           = null
    attributes          = []
    tags                = {}
    additional_tag_map  = {}
    regex_replace_chars = null
    label_order         = []
    id_length_limit     = null
    label_key_case      = null
    label_value_case    = null
    descriptor_formats  = {}
    labels_as_tags      = ["unset"]
  }
  description = <<-EOT
    Single object for setting entire context at once.
    See description of individual variables for details.
    Leave string and numeric variables as `null` to use default value.
    Individual variable settings (non-null) override settings in context object,
    except for attributes, tags, and additional_tag_map, which are merged.
  EOT

  validation {
    condition     = lookup(var.context, "label_key_case", null) == null ? true : contains(["lower", "title", "upper"], var.context["label_key_case"])
    error_message = "Allowed values: `lower`, `title`, `upper`."
  }

  validation {
    condition     = lookup(var.context, "label_value_case", null) == null ? true : contains(["lower", "title", "upper", "none"], var.context["label_value_case"])
    error_message = "Allowed values: `lower`, `title`, `upper`, `none`."
  }
}
```

### Variable Documentation
**See [documentation.instructions.md](./documentation.instructions.md) for comprehensive variable description best practices.**

Key points:
- Always include a `description` for every variable
- Variable descriptions are used by terraform-docs for input documentation
- Use clear, concise descriptions that explain purpose and usage
- For complex objects, document the structure and provide usage context
- Reference external documentation when relevant

### Variable Validation
Add validation blocks for variables with specific constraints:

```terraform
variable "task_cpu" {
  type        = number
  description = "value in cpu units for the task"

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.task_cpu)
    error_message = "Task CPU must be one of 256, 512, 1024, 2048, 4096, 8192, 16384"
  }
}
```

**Validation Best Practices:**
- Validate enums with `contains()` function
- Validate ARN formats with regex patterns
- Validate mutually exclusive options
- Validate conditional requirements
- Provide clear, actionable error messages

### Complex Object Variables
Use `optional()` for object attributes with sensible defaults:

```terraform
variable "secrets" {
  type = map(object({
    value          = optional(string)
    description    = optional(string)
    value_from_arn = optional(string)
  }))
  sensitive   = true
  description = "Map of secrets configuration"
  default     = {}
}
```

Mark sensitive variables with `sensitive = true`

## Locals

### Organization
Group related local values together and use multiple `locals` blocks for clarity:

```terraform
locals {
  # Feature flags
  scaling_enabled = var.autoscaling != null

  # Computed names
  container_names = [for definition in module.container_definitions : definition.json_map_object.name]
}

locals {
  # Complex transformations
  container_port_mappings = { for definition in module.container_definitions :
    definition.json_map_object.name => contains(keys(definition.json_map_object), "portMappings") ? definition.json_map_object.portMappings : []
  }
}
```

### Naming Conventions
- Use descriptive names that clearly indicate purpose
- Use boolean prefixes for flags: `enable_`, `create_`, `has_`, `is_`
- Use plural names for collections: `secret_arns`, `param_arns`

### Common Patterns

**Conditional Resource Creation:**
```terraform
locals {
  create_access_logs_bucket = var.enable_access_logs && var.create_access_logs_bucket
  enable_access_logs        = var.enable_access_logs && (var.create_access_logs_bucket || var.access_logs_bucket_name != null)
}
```

**Resource Merging:**
```terraform
locals {
  secrets = merge(data.aws_secretsmanager_secret.existing, aws_secretsmanager_secret.secrets)
  params  = merge(data.aws_ssm_parameter.existing, aws_ssm_parameter.param)
}
```

**ARN Lists:**
```terraform
locals {
  secret_arns = [for _key, secret in local.secrets : secret.arn]
  param_arns  = [for _key, param in local.params : param.arn]
  arns        = concat(local.secret_arns, local.param_arns)
}
```

## Resources

### Resource Naming

**Primary Resources:**
Use `this` as the identifier for the module's primary resource:

```terraform
resource "aws_ecs_service" "this" {
  name = module.label.id
  # ...
}

resource "aws_lb" "this" {
  name = module.label.id
  # ...
}
```

**Multiple/Supporting Resources:**
Use descriptive identifiers that convey purpose. **Avoid duplicating the resource type in the identifier.**

```terraform
# ✅ Good - identifier describes purpose, not type
resource "aws_iam_role" "execution" {
  # Role for ECS task execution
}

resource "aws_iam_role" "task" {
  # Role for ECS task
}

resource "aws_iam_role_policy_attachment" "execution_ecr_public" {
  # Descriptive name for specific purpose
}

# ❌ Bad - identifier duplicates the resource type
resource "aws_iam_role" "role" {
  # Redundant naming
}

resource "aws_security_group" "security_group" {
  # Redundant naming
}
```

**Rule:** When naming resources, ensure the identifier adds meaningful context rather than repeating information already present in the resource type.

### Dynamic Blocks
Use dynamic blocks for optional or repeating configuration:

```terraform
dynamic "access_logs" {
  for_each = local.enable_access_logs ? [1] : []

  content {
    bucket  = local.access_logs_bucket
    enabled = var.enable_access_logs
    prefix  = var.access_logs_prefix
  }
}

dynamic "ingress" {
  for_each = var.ingress_rules

  content {
    description      = ingress.value.description
    from_port        = ingress.value.from_port
    to_port          = ingress.value.to_port
    protocol         = ingress.value.protocol
    cidr_blocks      = ingress.value.cidr_blocks
    security_groups  = ingress.value.security_groups
  }
}
```

### Conditional Resource Creation
Use `count` or `for_each` for conditional resources:

```terraform
resource "aws_appautoscaling_target" "this" {
  count = local.scaling_enabled ? 1 : 0
  # ...
}

resource "aws_secretsmanager_secret" "secrets" {
  for_each = toset(local.secrets_to_actually_create)
  # ...
}
```

### Resource Dependencies
Reference resources appropriately:
- Access attributes directly: `aws_ecs_service.this.name`
- Use conditional references: `try(aws_ecs_service.this.service_connect_configuration[0].service[0].discovery_name, null)`
- For count-based resources: `aws_appautoscaling_target.this[0].resource_id`

## Outputs

**See [documentation.instructions.md](./documentation.instructions.md) for comprehensive output description best practices.**

### Output Structure
Provide comprehensive outputs with descriptions:

```terraform
output "service_arn" {
  value       = aws_ecs_service.this.id
  description = "The ARN of the service"
}

output "label_context" {
  value       = module.label.context
  description = "Context of the label for subsequent use"
}
```

Key points:
- Output descriptions are used by terraform-docs for output documentation
- Describe what is returned and how it should be used
- Document data structures for complex outputs
- Indicate integration points with other resources

### Output Patterns

**Map Outputs:**
```terraform
output "secrets" {
  value = {
    for key, secret in local.secrets : key => {
      arn         = secret.arn
      id          = secret.id
      name        = secret.name
      description = secret.description
    }
  }
  description = "Map of secrets metadata (excluding secret values)"
}
```

**List Outputs:**
```terraform
output "secret_arns" {
  value       = local.secret_arns
  description = "List of ARNs of the secrets - to use in IAM policies"
}
```

**Conditional Outputs:**
```terraform
output "scaling_target" {
  value       = local.scaling_enabled ? aws_appautoscaling_target.this[0] : null
  description = "The autoscaling target resource"
}

output "kms_key_arn" {
  value       = length(data.aws_kms_key.kms_key) > 0 ? data.aws_kms_key.kms_key[0].arn : null
  description = "ARN of the KMS key used to encrypt values"
}
```

**Container Definition Outputs:**
```terraform
output "container_definition" {
  value       = local.container_definitions
  description = "List of maps in the format: { name = <name>, valueFrom = <arn> } - to use in container definitions"
}
```

## Security & Compliance

### Checkov Skip Comments
Use security scan skip comments with clear justifications:

```terraform
resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:Access logging is not required, but configurable and recommended
  #checkov:skip=CKV2_AWS_28:WAF not implemented yet - planned for future (TODO)
  # ...
}
```

**Format:** `#checkov:skip=<CHECK_ID>:<REASON>`
- Always provide reason
- Use "TODO" for planned improvements

### Security Requirements

**Code-level security:**
- Mark sensitive variables: `sensitive = true`
- Never hardcode secrets - use variables or data sources
- Drop invalid headers: `drop_invalid_header_fields = true` (load balancers)
- Enable KMS encryption for secrets and sensitive data
- Make deletion protection configurable for critical resources

**Validation requirements:**
- ✅ Run security scanners: `checkov`, `tfsec`, or `trivy`
- ✅ Review IAM permissions (least privilege)
- ✅ Check security group rules (no overly permissive access)
- ✅ Ensure encryption at rest and in transit
- ✅ Enable audit logging where applicable

## Version Constraints

**Standard versions.tf:**

```terraform
terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.9"  # Use >= 6.0 for modules requiring newer features
    }
  }
}
```

**Required versions:**
- Terraform: >= 1.3
- AWS Provider: >= 4.9 (>= 6.0 for newer modules)
- CloudPosse label: 0.25.0 (exact version)

**Principle:** Use minimum viable versions to maximize compatibility, only increase when features require it.

## Code Style

### Formatting Standards

**Indentation and Spacing:**
- Use **2 spaces** for each nesting level (never tabs)
- Separate top-level blocks with **1 blank line**
- Separate nested blocks from arguments with **1 blank line**
- No trailing whitespace

**Argument Ordering within Blocks:**

1. **Meta-arguments first:** `count`, `for_each`, `depends_on`, `provider`
2. **Required arguments:** In logical order
3. **Optional arguments:** In logical order
4. **Nested blocks:** After all arguments
5. **Lifecycle blocks:** Last, with blank line separation

**Example:**
```terraform
resource "aws_instance" "example" {
  # Meta-arguments first
  count = var.instance_count

  # Required arguments
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # Optional arguments
  monitoring             = true
  associate_public_ip_address = false

  # Nested blocks
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = module.label.tags

  # Lifecycle block last
  lifecycle {
    create_before_destroy = true
  }
}
```

**Alignment:**
- Align `=` signs when multiple single-line arguments appear consecutively
- This improves readability for similar arguments
- Break alignment for nested blocks or when it reduces readability

```terraform
# Good - aligned for readability
resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = var.subnet_id

  tags = {
    Name        = "example"
    Environment = "production"
  }
}
```

**Variable and Output Ordering:**

**Rule:** Variables and outputs must be in **alphabetical order**, with one exception:
- The `context` variable must always be **first** in `variables.tf`

**Example:**
```terraform
# variables.tf
variable "context" {
  # Always first - CloudPosse label context
}

variable "assign_public_ip" {  # Alphabetical order starts here
variable "container_definitions" {}
variable "desired_count" {}
variable "ecs_cluster_name" {}
variable "name" {}
# ... etc
```

**Why:** Improves discoverability and maintains consistency across modules.

**Grouping (optional):** Use comment headers to group related variables, but maintain alphabetical order within groups.

### Formatting
- Use 2 spaces for indentation
- Align equals signs within blocks for readability
- Use blank lines to separate logical groups
- Keep line length reasonable (avoid excessive horizontal scrolling)

### Comments
- Document complex logic with inline comments
- Explain non-obvious decisions
- Use TODO comments for planned improvements
- Keep comments concise and relevant

### Null Safety
- Use `optional()` with default values
- Use `try()` for potentially null references
- Use `one()` for single-element lists from optional resources
- Use `lookup()` with defaults for map access

### Type Checking
Use `contains(keys(...), "key")` to check for object keys safely:

```terraform
container_cpu = local.container_definitions[count.index].cpu
container_memory = contains(keys(local.container_definitions[count.index]), "memory") ?
  local.container_definitions[count.index].memory : null
```

## IAM Policy Documents

### Structure
Use data sources for IAM policies:

```terraform
data "aws_iam_policy_document" "secrets_access" {
  count = local.has_secrets ? 1 : 0

  statement {
    sid    = join("", [module.base_id.id, "SecretsAccess"])
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = local.secret_arns
  }
}
```

**Best Practices:**
- Use descriptive SIDs (statement IDs)
- Use `join("", [...])` for constructing unique SIDs
- Separate different permission types into distinct statements
- Make policies conditional based on feature usage

## Module Integration

### Using External Modules
Reference specific versions:

```terraform
module "container_definitions" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.2"
  # ...
}
```

### Passing Context
Pass label context to nested modules:

```terraform
module "access_logs_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  context    = module.label.context
  attributes = [var.access_logs_bucket_config.name]
}
```

## Testing & Validation

### Pre-commit Checks
Ensure code passes:
- `terraform fmt` - Format code to standard style
- `terraform validate` - Validate configuration syntax
- `tflint` - Lint for best practices and errors
- Security scanning (checkov/tfsec)

### Variable Validation
Thoroughly validate inputs:
- Required vs optional attributes
- Mutually exclusive options
- Format validations (ARNs, IDs, etc.)
- Enum values
- Conditional requirements

## Post-Generation Workflow

**After generating or modifying Terraform code, run these checks in order:**

### 1. Format Code
```bash
terraform fmt -recursive     # Format all .tf files
terraform fmt -check -recursive  # Verify without changes
```
Verify: 2-space indentation, aligned `=`, proper spacing

### 2. Validate Syntax
```bash
terraform init
terraform validate
```

### 3. Lint for Best Practices
```bash
tflint --init && tflint
```

### 4. Security Scan
```bash
checkov -d .    # or: tfsec . or trivy config .
```
Check:
- No hardcoded secrets
- Proper variable usage for sensitive values
- IAM least privilege
- Security group rules
- Encryption enabled

### 5. Documentation Check
- ✅ All variables have descriptions
- ✅ All outputs have descriptions
- ✅ README includes examples
- ✅ Alphabetical ordering (context first)

### 6. Test Examples (if present)
```bash
cd examples/basic
terraform init && terraform validate && terraform plan
```

## Best Practices Checklist

### Required for All Modules

- ✅ **Never** hardcode secrets or sensitive values - use variables
- ✅ **Always** use latest compatible provider versions
- ✅ **Always** make provider versions friendly to older versions (limit only when required)
- ✅ **Always** follow proper formatting (2-space indentation, aligned `=`)
- ✅ **Always** document provider/module sources in comments
- ✅ **Always** follow alphabetical ordering for variables/outputs (context first)
- ✅ **Always** use descriptive resource names
- ✅ **Always** include README with usage examples
- ✅ **Always** review security implications
- ✅ **Always** validate input variables with appropriate constraints

### Security Best Practices

1. **Variable Security:** Use workspace/environment variables for sensitive values
2. **Access Control:** Implement proper IAM permissions and least privilege
3. **Resource Tagging:** Include consistent tagging for cost allocation and governance
4. **Encryption:** Enable encryption for data at rest and in transit
5. **Network Security:** Use security groups and NACLs appropriately
6. **Audit Logging:** Enable CloudTrail, flow logs, and access logs

### Module Design Best Practices

1. **Single Responsibility:** Each module should have one clear purpose
2. **Composability:** Design modules to work well together
3. **Flexibility:** Use variables for all configurable aspects
4. **Sensible Defaults:** Provide defaults that work for most use cases
5. **Documentation:** Comprehensive README and inline documentation
6. **Examples:** Multiple examples showing different use cases
7. **Testing:** Include test configurations and validation

## Additional Resources

- [Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)
- [Module Development Best Practices](https://developer.hashicorp.com/terraform/language/modules/develop)
- [Terraform Registry Publishing](https://developer.hashicorp.com/terraform/registry/modules/publish)
- [Terraform Testing](https://developer.hashicorp.com/terraform/language/tests)
- [terraform-docs](https://terraform-docs.io/) - Generate documentation from Terraform modules
- [tflint](https://github.com/terraform-linters/tflint) - Terraform linter
- [checkov](https://www.checkov.io/) - Static code analysis for IaC
- [tfsec](https://aquasecurity.github.io/tfsec/) - Security scanner for Terraform
