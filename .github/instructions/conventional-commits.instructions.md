# Conventional Commits for Pull Requests

## Overview

All pull request titles MUST follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification. This standard is used for automated versioning and release note generation.

## Format

```
<type>[!]: <description>
```

Where:
- `<type>` is one of the allowed types (see below)
- `!` is an optional suffix indicating a **breaking change**
- `<description>` is a brief, lowercase description of the change

## Allowed Types

### `feat:` - New Features
Used for new functionality that adds value to the module.

**Examples:**
- `feat: add support for custom tags`
- `feat: implement automatic scaling configuration`
- `feat!: change variable naming convention` (breaking change)

**Version Impact:** Minor version bump (`0.1.0` → `0.2.0`)
**Version Impact (with `!`):** Major version bump (`0.1.0` → `1.0.0`)

### `fix:` - Bug Fixes
Used for fixes that correct module behavior without adding new features.

**Examples:**
- `fix: correct validation logic for security group rules`
- `fix: resolve resource naming conflict`
- `fix!: change default value for enable_monitoring` (breaking change)

**Version Impact:** Patch version bump (`0.1.0` → `0.1.1`)
**Version Impact (with `!`):** Major version bump (`0.1.0` → `1.0.0`)

### `chore:` - Maintenance
Used for internal changes that don't affect module functionality (tests, CI, refactoring).

**Examples:**
- `chore: update pre-commit hooks`
- `chore: refactor internal helper functions`
- `chore!: drop support for Terraform 1.4` (breaking change)

**Version Impact:** Patch version bump (`0.1.0` → `0.1.1`)
**Version Impact (with `!`):** Major version bump (`0.1.0` → `1.0.0`)

## Breaking Changes

Any type can be marked as a breaking change by adding `!` after the type:

```
feat!: remove deprecated variable
fix!: change default region to eu-west-1
chore!: require Terraform 1.6+
```

**Breaking changes ALWAYS result in a major version bump.**

## Additional Types (Optional)

While `feat`, `fix`, and `chore` are the primary types, these are also supported:

- `docs:` - Documentation only changes
- `style:` - Code style/formatting (no functional changes)
- `refactor:` - Code refactoring (no functional changes)
- `perf:` - Performance improvements
- `test:` - Adding or updating tests
- `build:` - Build system or dependency changes
- `ci:` - CI/CD configuration changes
- `revert:` - Reverting previous changes

## Labels

The GitHub labeler automatically applies labels based on PR titles:

| Title Pattern | Version Label | Type Labels |
|--------------|---------------|-------------|
| `feat:` | `version: minor` | `feature` |
| `feat!:` | `version: major` | `feature` |
| `fix:` | `version: patch` | `bug` |
| `fix!:` | `version: major` | `bug` |
| `chore:` | `version: patch` | `chore`, `maintenance` |
| `chore!:` | `version: major` | `chore`, `maintenance` |
| Any `<type>!:` | `version: major` | (type-specific) |

## Release Notes

The conventional commit type prefix is automatically removed from release notes:

**PR Title:** `feat: add support for custom tags`
**In Release Notes:** `add support for custom tags`

## Guidelines

1. **Use lowercase** for the description
2. **No period** at the end of the description
3. **Imperative mood** - "add feature" not "adds feature" or "added feature"
4. **Be concise** - Keep descriptions under 72 characters when possible
5. **Be specific** - Describe what changed, not why (use PR description for "why")

## Examples

✅ **Good:**
```
feat: add encryption at rest support
fix: correct IAM policy document syntax
chore: update terraform-docs to v0.18.0
feat!: remove deprecated enable_legacy_mode variable
fix!: change default vpc_id to required
```

❌ **Bad:**
```
Add encryption  (missing type)
feat:Add encryption  (missing space after colon)
feat: Added encryption support.  (not imperative, has period)
feat: ENCRYPTION SUPPORT  (uppercase)
Fixed a bug  (missing type)
chore: stuff  (too vague)
```

## Copilot Integration

When creating PRs through Copilot:
1. Copilot will automatically generate PR titles following this format
2. Always review the generated title for accuracy
3. Ensure the type correctly reflects the change
4. Add `!` if the change is breaking
5. Adjust the description to be clear and concise

## References

- [Conventional Commits Specification](https://www.conventionalcommits.org/en/v1.0.0/)
- [Semantic Versioning](https://semver.org/)
- Repository labeler configuration: `.github/labeler.yml`
- Repository release drafter configuration: `.github/release-drafter.yml`
