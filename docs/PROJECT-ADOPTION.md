# Shared CI project adoption

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

Replace both placeholders with the same reviewed 40-character commit SHA. The workflow intentionally has no default for `platform-ref`; callers cannot silently track a moving branch. The example uses manual dispatch until a dedicated isolated runner is secured and registered. Do not add fork pull-request triggers or enable automatic triggers on a persistent self-hosted runner.

The workflow runs the platform core smoke suite, non-provisioning host-safety suite, and real Windows filesystem-link integration suite before executing the consumer config. The link test creates a unique temporary fixture, requires a real junction, and reports SKIP if symbolic-link creation is not permitted.

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
