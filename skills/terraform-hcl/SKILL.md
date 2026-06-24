---
name: terraform-hcl
description: Expert Terraform and HCL module guidance grounded in Cloud Posse and AWS IA Terraform standards. Use when Codex is asked to write, review, refactor, plan, or debug Terraform/HCL files, Terraform module repositories, provider blocks, variables, outputs, dynamic resources, tagging and naming, state/backends, tests, generated docs, release conventions, or Terraform Registry readiness.
---

# Terraform HCL

## Overview

Work as a Terraform module and HCL standards reviewer. Favor small, composable, opinionated modules with stable interfaces, clear root-vs-child boundaries, safe state handling, and automated validation.

## First Moves

- Read nearby Terraform files, repo docs, and CI/pre-commit config before applying generic standards.
- Prefer local conventions when they are explicit and coherent. If local patterns are weak or absent, apply [standards.md](references/standards.md).
- Load [standards.md](references/standards.md) for any non-trivial module design, review, refactor, or repository-structure work.
- Challenge modules that only wrap provider resources without expressing a use case. Push toward a narrower interface or plain inline Terraform.
- Before touching multiple Terraform modules or package roots, state the scope and why.

## Design Priorities

- Keep modules small, composable, and opinionated around a real deployment pattern.
- Treat root modules and reusable child modules differently. Root modules own provider configuration, backends, authentication, regions, profiles, assume-role chains, default tags, and environment-specific behavior.
- In child modules, declare `required_providers` and version constraints. For multiple provider instances, use `configuration_aliases` and document the caller's `providers` meta-argument.
- Design input variables as a stable API: snake_case names, descriptions, explicit types, positive booleans, validations, safe defaults, and `sensitive = true` for secrets.
- Prefer objects/maps for related configuration and `for_each` with stable keys for dynamic resources. Use `count` only for simple 0-or-1 toggles.
- Output values that consumers actually compose with. Do not output secrets.
- Protect root-module state with a remote backend, locking, encryption, versioning, and ignore rules for local state artifacts.
- Use consistent resource naming and tags. In Cloud Posse-style modules, prefer `terraform-null-label`; in AWS IA-style modules, prefer `terraform-aws-label`.
- Pin external module calls exactly. For provider constraints, use explicit `required_providers` constraints that fit the repo's upgrade policy.

## Hard Stops

- Do not put secrets in outputs, defaults, examples, generated docs, committed state, plans, or test fixtures.
- Do not configure provider authentication or arbitrary credential-chain choices inside reusable modules.
- Do not add backend blocks to reusable child modules; Terraform ignores child-module backend configuration.
- Do not use `default_tags` inside a child module; leave root modules in control.
- Do not use heredoc strings for JSON, YAML, or IAM policies when structured encoders or policy document data sources are available.
- Do not claim runtime behavior from code reading alone when a Terraform command can verify it.

## Common Workflows

For implementation:

- Inspect existing module shape, examples, tests, docs generation, and pre-commit/CI checks.
- Design the module API before editing resources: variables, outputs, naming, tags, provider aliases, and optional features.
- Keep standard module files conventional: `main.tf`, `variables.tf`, `outputs.tf`, and `versions.tf`; use provider configuration files only in root modules.
- Add or update examples for supported usage patterns.
- Add focused validation or tests when the change affects module behavior.

For review:

- Lead with concrete findings and file/line evidence.
- Prioritize unsafe root-module state handling, misplaced child-module backend blocks, provider boundary violations, secret exposure, unstable `count` usage, weak variable contracts, missing tests/examples, and generated-doc drift.
- Distinguish repo convention issues from standards issues. Do not force Cloud Posse naming helpers into an AWS IA repo, or the reverse, without a clear reason.

## Verification

Prefer the smallest command that checks the changed behavior:

```sh
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform test
tflint --recursive
terraform-docs .
pre-commit run --all-files
```

Use repo-specific wrappers, task runners, or CI commands when present.
