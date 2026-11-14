# Shared CI Platform

A portable command-based CI runner for local development and dedicated self-hosted Windows runners. MotionDeck Studio is the first adopter; the platform is designed for reuse across independent repositories.

## Status

**Bootstrap — not yet runtime-validated.** The release manifest currently identifies `0.1.0` as a bootstrap target, not a production release. See [release gates](docs/REPOSITORY-BOOTSTRAP.md).

## Features

- PowerShell 7 command runner with explicit executable + argument arrays (no implicit shell command strings).
- Project configuration contract and JSON Schema v1.
- Starter presets for Node.js, Python and .NET.
- Timestamped JSON, Markdown, stdout/stderr and log reports.
- Project-root path confinement for config, output and step working directories.
- Smoke fixtures for successful execution and intentional exit-code-23 failure.

## Quick start

1. Copy `ci.project.example.json` to `ci.project.json` in the consuming repository.
2. Edit project name, commands and working directories.
3. From the consuming repository root, run:

   ```powershell
   pwsh -NoProfile -File <path-to-shared-ci>/scripts/run.ps1 -ConfigPath ci.project.json
   ```

4. Inspect `artifacts/ci/` for the generated reports.

The runner does not install dependencies or access the network unless an explicitly configured step does so.

## Project adoption

- [Project adoption guide](docs/PROJECT-ADOPTION.md)
- [Adapter contract](docs/ADAPTER-CONTRACT.md)
- [Standalone bootstrap and release gates](docs/REPOSITORY-BOOTSTRAP.md)
- [Smoke project](examples/smoke-project/README.md)
- [Release manifest](RELEASE-MANIFEST.json)

## Reusable workflow

The reusable workflow is available at `.github/workflows/reusable.yml`. A consumer calls it from a protected-branch workflow and must register a dedicated self-hosted runner with labels `self-hosted`, `Windows`, `X64`, and `shared-ci`.

Never run untrusted fork pull-request code on a privileged self-hosted runner. Do not enable the workflow until the runner is secured, registered and online. The workflow intentionally does not use GitHub-hosted runners.

## Security

- Use a dedicated least-privilege runner account and isolated work directory.
- Keep credentials out of project configuration and logs.
- Prefer protected-branch pushes and manual dispatch.
- Pin reusable workflow calls to a reviewed release tag or commit SHA.
- Treat self-hosted runner machines as sensitive infrastructure that requires patching and monitoring.
