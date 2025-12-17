---
applyTo: "examples/**/*,README.md"
---

# Terraform Module Examples Instructions

## Quick Reference

**When creating examples:**
- README must include: Minimal Setup + Advanced Setup
- Examples directory structure: `examples/{basic,complete,scenario}/`
- Each example needs: main.tf, variables.tf, outputs.tf, versions.tf, README.md
- Use `source = "../../"` for local module references
- Test all examples: `terraform init`, `terraform validate`, `terraform plan`
- Document purpose, prerequisites, and cleanup in example README

**Cross-references:**
- README documentation → [documentation.instructions.md](./documentation.instructions.md)
- Terraform code style → [terraform.instructions.md](./terraform.instructions.md)

---

## Overview

Examples are a critical part of module documentation, demonstrating real-world usage patterns and helping users quickly understand how to implement the module. This guide covers both inline examples in the main README.md and separate example configurations in the `examples/` directory.

## Main README.md Examples

**See [documentation.instructions.md](./documentation.instructions.md) for README structure and formatting.**

The Examples section in the main README.md should contain:

### 1. Minimal Setup (Required)

Provide a basic example showing the absolute minimum required configuration.

**Purpose:**
- Help users get started quickly
- Show only required variables
- Demonstrate the simplest use case
- Serve as a starting point for customization

**Example:**

```markdown
## Examples

### Minimal Setup

```terraform
module "basic_service" {
  source = "github.com/Luscii/terraform-aws-ecs-service"

  name            = "my-service"
  ecs_cluster_name = "production"
  vpc_id          = "vpc-12345678"
  subnets         = ["subnet-12345678", "subnet-87654321"]

  task_cpu    = 256
  task_memory = 512

  container_definitions = [{
    name  = "app"
    image = "nginx:latest"
  }]

  task_role      = { name = "task-role", arn = "arn:aws:iam::123456789012:role/task-role" }
  execution_role = { name = "exec-role", arn = "arn:aws:iam::123456789012:role/exec-role" }

  context = module.label.context
}
```
```

**Best Practices for Minimal Examples:**
- Include all required variables
- Use sensible default values
- Show context integration (CloudPosse label)
- Keep it under 30 lines when possible
- Avoid optional features
- Use realistic but generic values

### 2. Extended/Advanced Setup (Required)

Provide an advanced example showing common optional features and integrations.

**Purpose:**
- Demonstrate real-world usage
- Show integration with other resources
- Highlight important optional features
- Provide a production-ready example

**Example:**

```markdown
### Advanced Setup with Load Balancer and Autoscaling

```terraform
module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace   = "luscii"
  environment = "production"
  name        = "api"
}

module "advanced_service" {
  source = "github.com/Luscii/terraform-aws-ecs-service"

  name             = module.label.name
  ecs_cluster_name = "production"
  vpc_id           = "vpc-12345678"
  subnets          = ["subnet-12345678", "subnet-87654321"]

  task_cpu    = 1024
  task_memory = 2048

  container_definitions = [{
    name  = "app"
    image = "myregistry.io/api:v1.2.3"

    port_mappings = [{
      containerPort = 8080
      protocol      = "tcp"
      name          = "http"
    }]

    environment = [
      { name = "ENVIRONMENT", value = "production" },
      { name = "LOG_LEVEL", value = "info" }
    ]

    secrets = module.secrets.container_definition
  }]

  load_balancers = [{
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "app"
    container_port   = 8080
  }]

  scaling = {
    min_capacity = 2
    max_capacity = 10
  }

  scaling_target = {
    cpu = {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
      target_value           = 70
    }
  }

  task_role      = module.task_role.role
  execution_role = module.execution_role.role

  context = module.label.context
}

# Using module outputs
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  alias {
    name                   = module.load_balancer.dns_name
    zone_id                = module.load_balancer.zone_id
    evaluate_target_health = true
  }
}
```
```

**Best Practices for Advanced Examples:**
- Show realistic production configurations
- Demonstrate module output usage
- Include integration with related resources
- Show CloudPosse label context usage
- Include comments for complex configurations
- Demonstrate multiple features working together
- Keep it under 100 lines when possible

### 3. Additional Scenario Examples (Optional)

For modules with distinct use cases, provide additional inline examples:

```markdown
### Service Connect Only (No Load Balancer)

```terraform
module "internal_service" {
  source = "github.com/Luscii/terraform-aws-ecs-service"

  # ... configuration

  service_connect_configuration = {
    namespace      = "internal"
    discovery_name = "api"
    port_name      = "http"
    client_alias = {
      dns_name = "api.internal"
      port     = 8080
    }
  }
}
```
```

## Examples Directory Structure

**When to Create an Examples Directory:**
- Module supports multiple distinct use cases
- Configurations are too complex for inline examples
- You want to provide tested, working examples
- Users benefit from seeing complete, runnable configurations

### Standard Structure

```
examples/
  ├── README.md                 # Overview of all examples
  ├── basic/                    # Minimal working example
  │   ├── main.tf
  │   ├── variables.tf
  │   ├── outputs.tf
  │   ├── versions.tf
  │   └── README.md
  ├── complete/                 # Full-featured example
  │   ├── main.tf
  │   ├── variables.tf
  │   ├── outputs.tf
  │   ├── versions.tf
  │   └── README.md
  └── {scenario}/               # Use-case specific example
      ├── main.tf
      ├── variables.tf
      ├── outputs.tf
      ├── versions.tf
      └── README.md
```

### Common Scenario Directories

Create separate directories for common use cases:

**For ECS Service Module:**
- `with-load-balancer/` - Service behind an ALB
- `service-connect-only/` - Internal service using Service Connect
- `scheduled-task/` - Scheduled ECS task
- `with-autoscaling/` - Service with auto-scaling enabled

**For Load Balancer Module:**
- `public-alb/` - Internet-facing load balancer
- `internal-alb/` - Internal load balancer
- `with-waf/` - Load balancer with WAF integration

**For Secrets Module:**
- `new-secrets/` - Creating new secrets
- `existing-secrets/` - Using existing secrets
- `mixed/` - Combination of new and existing

### Example Directory Files

#### main.tf

Contain the complete, working configuration:

```terraform
module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace   = var.namespace
  environment = var.environment
  name        = var.name
}

module "example" {
  source = "../../"  # Reference the parent module

  # Complete configuration for this scenario
  name = module.label.name
  # ...

  context = module.label.context
}
```

**Best Practices:**
- Use `source = "../../"` to reference the parent module
- Include all necessary provider configurations
- Use variables for customizable values
- Add comments explaining key decisions
- Keep it self-contained and runnable

#### variables.tf

Provide variables for customization:

```terraform
variable "namespace" {
  type        = string
  description = "Namespace for resource naming"
  default     = "example"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

variable "name" {
  type        = string
  description = "Name of the resource"
  default     = "demo"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-1"
}
```

**Best Practices:**
- Provide sensible defaults
- Include descriptions
- Make infrastructure IDs customizable (VPC, subnets, etc.)
- Allow region configuration

#### outputs.tf

Expose useful outputs:

```terraform
output "service_name" {
  value       = module.example.service_name
  description = "Name of the created service"
}

output "service_arn" {
  value       = module.example.service_arn
  description = "ARN of the created service"
}

output "service_url" {
  value       = module.example.service_discovery_internal_url
  description = "Internal URL for the service"
}
```

#### versions.tf

Specify version constraints:

```terraform
terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
```

#### README.md (Example-specific)

Each example must have its own README explaining:

**Required Content:**

```markdown
# {Scenario Name}

## Purpose

Brief description of what this example demonstrates and when to use it.

## What This Example Deploys

- List of resources created
- Key features demonstrated
- Integration points shown

## Usage

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

## Configuration

Key configuration points:

- **Variable X**: Explanation of important variable
- **Feature Y**: Why this feature is configured this way

## Cleanup

```bash
terraform destroy
```

## Notes

Any important notes, limitations, or prerequisites.
```

**Example - Complete README:**

```markdown
# ECS Service with Load Balancer

## Purpose

Demonstrates deploying an ECS Fargate service behind an Application Load Balancer with auto-scaling capabilities. Use this example when you need a publicly accessible service that can scale based on load.

## What This Example Deploys

- ECS Fargate service with 2 tasks
- Application Load Balancer (ALB)
- Target group for health checks
- Auto-scaling configuration (CPU-based)
- Security groups for ALB and ECS service
- CloudWatch log group for container logs

## Prerequisites

- Existing VPC with public and private subnets
- ECS cluster
- IAM roles for task and execution

## Usage

```bash
# Set required variables
export TF_VAR_vpc_id="vpc-12345678"
export TF_VAR_subnet_ids='["subnet-12345678","subnet-87654321"]'

# Initialize and apply
terraform init
terraform plan
terraform apply
```

## Configuration

Key configuration points:

- **Load Balancer**: Deployed in public subnets, forwards traffic to ECS tasks in private subnets
- **Auto-scaling**: Scales between 2-10 tasks based on CPU utilization > 70%
- **Health Checks**: Target group performs HTTP health checks on `/health` endpoint
- **Networking**: Service uses awsvpc network mode for ENI-per-task

## Testing

After deployment:

```bash
# Get the load balancer DNS
terraform output alb_dns_name

# Test the endpoint
curl http://$(terraform output -raw alb_dns_name)/
```

## Cleanup

```bash
terraform destroy
```

## Notes

- This example assumes you have an existing VPC and ECS cluster
- Container image should expose port 8080 and respond to health checks on `/health`
- Auto-scaling might take 3-5 minutes to trigger after load increase
```

## examples/README.md

The root examples README provides navigation to all examples.

**Required Structure:**

```markdown
# Examples

This directory contains examples demonstrating various ways to use this module.

## Available Examples

### [Basic Example](./basic/)

Minimal configuration showing the essential inputs required to use this module.

**Use this when:** You want the simplest possible setup to get started.

**Demonstrates:**
- Required variables only
- Minimal working configuration
- Basic module usage

---

### [Complete Example](./complete/)

Full-featured configuration demonstrating all major features and optional parameters.

**Use this when:** You need a production-ready configuration with common features.

**Demonstrates:**
- All important optional features
- Integration with other AWS services
- Output usage
- Production best practices

---

### [{Scenario Name}](./{scenario}/)

Brief description of the scenario.

**Use this when:** Specific use case description.

**Demonstrates:**
- Key feature 1
- Key feature 2
- Integration pattern

---

## Running Examples

Each example is self-contained. To run an example:

```bash
cd {example-directory}
terraform init
terraform plan
terraform apply
```

## Prerequisites

Common prerequisites for all examples:

- Terraform >= 1.3
- AWS Provider >= 6.0
- Valid AWS credentials configured
- [List any specific AWS resources needed]

## Cleaning Up

To remove resources created by an example:

```bash
cd {example-directory}
terraform destroy
```
```

## Best Practices

### Example Quality

1. **Working Code:**
   - All examples must be tested and working
   - Run `terraform plan` and `terraform apply` to verify
   - Include any necessary data sources or resources

2. **Self-Contained:**
   - Each example should be independently runnable
   - Include all required configurations
   - Don't depend on external state or resources (except documented prerequisites)

3. **Realistic:**
   - Use realistic naming conventions
   - Show production-like configurations
   - Demonstrate actual use cases

4. **Documented:**
   - Explain what the example does
   - Document why specific choices were made
   - Include usage instructions

### Placeholder Conventions

**In Code Comments:**
```terraform
# Replace with your VPC ID
vpc_id = "vpc-12345678"
```

**In README:**
- Use angle brackets: `<VPC_ID>`, `<SUBNET_ID>`
- Provide example values: "e.g., vpc-12345678"
- List where to find the values

**In Variables:**
- Provide sensible defaults when possible
- Use variables for infrastructure IDs
- Document what values are needed

### Testing Examples

Before committing:

1. **Initialize:** `terraform init` succeeds
2. **Validate:** `terraform validate` passes
3. **Format:** `terraform fmt` applied
4. **Plan:** `terraform plan` completes without errors
5. **Apply:** (Optional) Test actual deployment
6. **Documentation:** README is complete and accurate

### Maintenance

1. **Keep Updated:**
   - Update when module interface changes
   - Update provider versions periodically
   - Test after Terraform version updates

2. **Version References:**
   - Use `source = "../../"` for local module reference
   - Pin external module versions
   - Document version compatibility

3. **Dependencies:**
   - Minimize external dependencies
   - Document required resources clearly
   - Provide data source examples for lookup

## Example Checklist

Before finalizing an example:

- [ ] Example has a clear, specific purpose
- [ ] All required files are present (main.tf, variables.tf, outputs.tf, versions.tf, README.md)
- [ ] Code is formatted (`terraform fmt`)
- [ ] Code validates (`terraform validate`)
- [ ] Variables have descriptions and sensible defaults
- [ ] Outputs are documented
- [ ] README explains purpose, usage, and cleanup
- [ ] Prerequisites are documented
- [ ] Example has been tested
- [ ] Module source reference is correct
- [ ] Version constraints are specified
- [ ] Comments explain non-obvious choices

## Anti-Patterns to Avoid

1. **Empty Examples:**
   - Don't create placeholder examples
   - Every example must be complete and working

2. **Over-Complicated:**
   - Don't try to demonstrate everything in one example
   - Keep each example focused on specific use case

3. **Undocumented:**
   - Don't assume users will understand without explanation
   - Document why, not just what

4. **Hardcoded Values:**
   - Use variables for customizable values
   - Provide defaults but allow overrides

5. **Missing Context:**
   - Don't skip CloudPosse label context
   - Show how the module fits in larger infrastructure

6. **Untested:**
   - Don't commit examples that haven't been validated
   - Run at least `terraform plan` to verify

## Integration with CI/CD

Consider adding example validation to CI:

```yaml
# .github/workflows/examples.yml
name: Validate Examples

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        example: [basic, complete, scenario1, scenario2]
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - name: Validate Example
        run: |
          cd examples/${{ matrix.example }}
          terraform init
          terraform validate
          terraform fmt -check
```
