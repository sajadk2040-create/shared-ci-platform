# Shared CI project adoption

## Consumer starter template

Start with [`examples/consumer-template/`](../examples/consumer-template/README.md). It contains a minimal v1 config, a PowerShell repository smoke script, and a manual-only reusable-workflow example. Copy the files into the consumer repository and replace the sample project name and checks.

For local validation, install PowerShell 7 and run the platform directly from the consumer repository root:

```powershell
pwsh -NoProfile -File <path-to-shared-ci>/scripts/run.ps1 -ConfigPath ci.project.example.json
```

This local path does not require GitHub Actions, a registered runner, or any account/ACL/service changes. The starter smoke script only checks for a root `README.md`; replace it with meaningful project-specific checks before relying on it.

## Consumer repository

A consumer uses the reusable workflow from this repository and must pass an immutable platform revision explicitly:

```yaml
name: CI
on:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  shared:
    uses: sajadk2040-create/shared-ci-platform/.github/workflows/reusable.yml@<reviewed-workflow-commit-sha>
    with:
      config-path: ci.project.json
      platform-ref: <same-reviewed-workflow-commit-sha>
```

Replace both placeholders with the same reviewed 40-character commit SHA. The workflow intentionally has no default for `platform-ref`; callers cannot silently track a moving branch. The reusable workflow independently rejects non-`workflow_dispatch` caller events, requires `github.ref_protected == true`, and validates that `platform-ref` is exactly 40 hexadecimal characters before checking out the platform repository. Configure branch protection or a ruleset on the consumer branch used for manual dispatch. Do not add fork pull-request triggers or enable automatic triggers on a persistent self-hosted runner.

The reusable workflow pins its GitHub Actions to full commit SHAs. Report artifacts are retained for three days; they can still contain sensitive test output, so restrict repository access and inspect artifact contents before treating them as safe to share.

The workflow runs the platform core smoke suite, non-provisioning host-safety suite, and real Windows filesystem-link integration suite before executing the consumer config. The link test creates a unique temporary fixture, requires a real junction, and reports SKIP if symbolic-link creation is not permitted.

## Runner scope and registration

A reusable workflow job runs in the caller repository's context. A runner registered only at the shared-ci-platform repository scope is not automatically available to a different consumer repository. Before enabling a consumer, register a dedicated runner at that consumer repository scope, or use an organization runner group explicitly restricted to approved consumer repositories. Do not broaden runner access to all repositories. For this personal-account setup, a separate runner per consumer repository is the simpler supported model.

## Presets and schema

- Validate the project config against `schemas/ci-project.schema.json`.
- Copy `presets/node.json`, `presets/python.json`, or `presets/dotnet.json` and tailor it to the actual repository.
- See `ADAPTER-CONTRACT.md` for runtime reproducibility and security requirements.
- Node preset requires a committed package lockfile because it uses `npm ci`.

## Configuration contract (v1)

- `schemaVersion`: required integer, currently 1.
- `project.name`: required display name.
- `project.reportDirectory`: optional relative output path; defaults to `artifacts/ci`.
- `steps`: ordered array of explicit commands.
- Each step requires `name` and `command`; `args` and `workingDirectory` are optional.
- `continueOnError`: optional boolean; a failed step still appears in the report, but does not fail the whole run when true.

Commands are invoked directly without a shell, so shell metacharacters in arguments are not interpreted. The engine does not install dependencies, infer commands, or fetch code.

## Current constraints

The initial runner implementation targets PowerShell 7 on Windows. The reusable workflow requires the dedicated self-hosted labels `self-hosted`, `Windows`, `X64`, and `shared-ci`. Do not use this workflow with fork pull requests or other untrusted code.
