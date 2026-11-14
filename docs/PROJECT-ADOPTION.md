# Shared CI project adoption

## Consumer repository

A project opts in by adding `ci.project.json` at its root and a tiny caller workflow:

```yaml
name: CI
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  shared:
    uses: sajadk2040-create/shared-ci-platform/.github/workflows/reusable.yml@v0.1.0
```

The example assumes the `v0.1.0` release tag has been published. Until the PowerShell runtime and security release gates pass and that tag exists, do not enable this caller workflow. Pin the workflow to a reviewed release tag or immutable commit SHA.

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

The initial runner implementation targets PowerShell 7 on Windows. The workflow is deliberately pinned to a custom self-hosted label and must not be enabled before a runner with that label is online. Do not use this workflow with fork pull requests or other untrusted code.
