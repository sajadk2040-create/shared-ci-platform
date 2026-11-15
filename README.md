# Shared CI Platform

A portable command-based CI runner for local development and dedicated self-hosted Windows runners. MotionDeck Studio is the first adopter; the platform is designed for reuse across independent repositories.

## Status

**Local runtime validation passed for the core runner, and the full suite now runs in CI.** The eight-group PowerShell 7.6.9 core smoke suite, the five-group runner-host safety suite, the real Windows filesystem-link integration script and the smoke-project fixtures all passed on the repository's dedicated self-hosted Windows runner (`win-docker-01`, runner `2.338.2`, PowerShell `7.6.9`) via `.github/workflows/ci.yml`; see [CI validation results](docs/CI-VALIDATION-RESULTS.md) for the run IDs. The real-link script created an actual junction, so the previously outstanding Windows re-run of the host-safety and filesystem-link suites is now executed evidence. No provisioning, account creation, ACL mutation, runner registration or service installation is performed by the platform itself, and the runner still starts from `run.cmd` rather than a Windows service. Branch protection, the stacked security pull requests and the release gates remain outstanding: the release manifest's `0.1.0` is still a bootstrap target, not a production release, and no `v0.1.0` tag exists yet. See [release gates](docs/REPOSITORY-BOOTSTRAP.md).

## Features

- PowerShell 7 command runner with explicit executable + argument arrays (no implicit shell command strings).
- Project configuration contract and JSON Schema v1.
- Optional per-step timeout with best-effort descendant process-tree termination.
- Unique timestamp-plus-random run IDs to prevent concurrent report collisions.
- Starter presets for Node.js, Python and .NET.
- Timestamped JSON, Markdown, stdout/stderr and log reports; raw process arguments are not copied into JSON/log metadata.
- Project-root path confinement for config, output and step working directories.
- PowerShell smoke-test harness covering argument boundaries, report capture, exit-code handling, lexical traversal, Windows junction traversal, invalid-config rejection, timeout termination and concurrent runs.

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

- [Consumer starter template](examples/consumer-template/README.md) — copy-ready config, smoke script and manual-only workflow example.
- [Project adoption guide](docs/PROJECT-ADOPTION.md)
- [Consumer template validation](docs/CONSUMER-TEMPLATE-TESTS.md)
- [Adapter contract](docs/ADAPTER-CONTRACT.md)
- [Standalone import and validation status](docs/PORTING-STATUS.md)
- [Standalone bootstrap and release gates](docs/REPOSITORY-BOOTSTRAP.md)
- [CI validation results](docs/CI-VALIDATION-RESULTS.md)
- [Local PowerShell validation guide](docs/LOCAL-VALIDATION.md)
- [Self-hosted runner security review](docs/SELF-HOSTED-RUNNER-SECURITY-REVIEW.md)
- [Read-only runner host preflight](docs/RUNNER-HOST-PREFLIGHT.md)
- [Guarded runner host provisioning](docs/RUNNER-HOST-PROVISIONING.md)
- [Runner host safety tests](docs/RUNNER-HOST-SAFETY-TESTS.md)
- [Read-only runner isolation audit](docs/RUNNER-HOST-ISOLATION-AUDIT.md)
- `scripts/SharedCiAclRules.ps1`: reusable, independently testable ACL rule assessment.
- [Smoke project](examples/smoke-project/README.md)
- [Release manifest](RELEASE-MANIFEST.json)

## Reusable workflow

The reusable workflow is available at `.github/workflows/reusable.yml`. A consumer calls it from a workflow pinned to a reviewed immutable commit and must pass the same 40-character commit SHA as the required `platform-ref` input. The job requires a dedicated self-hosted runner with labels `self-hosted`, `Windows`, `X64`, and `shared-ci`. Before running the consumer config, the workflow executes the core smoke suite, host-safety suite, and real Windows filesystem-link integration test.

Never run untrusted fork pull-request code on a privileged self-hosted runner. Do not enable the workflow until the runner is secured, registered and online. The workflow intentionally does not use GitHub-hosted runners.

## License

This project is distributed under the [MIT License](LICENSE).

## Security

- Use a dedicated least-privilege runner account and isolated work directory.
- The runner rejects existing symlink/junction/reparse-point components in project-relative paths. This is defense-in-depth, not protection against a concurrent time-of-check/time-of-use filesystem race; keep the workspace isolated and execute trusted project configuration only.
- Keep credentials out of project configuration and logs.
- Prefer protected-branch pushes and manual dispatch.
- Pin reusable workflow calls to a reviewed release tag or commit SHA.
- Treat self-hosted runner machines as sensitive infrastructure that requires patching and monitoring.
