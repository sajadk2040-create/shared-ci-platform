# Standalone repository bootstrap

Target repository: `sajadk2040-create/shared-ci-platform`.

The current source is staged under `tooling/shared-ci/` inside MotionDeck. When the destination repository is created, copy the contents of this directory to its root with this mapping:

| Staging path | Standalone path |
|---|---|
| `scripts/run.ps1` | `scripts/run.ps1` |
| `schemas/` | `schemas/` |
| `presets/` | `presets/` |
| `docs/` | `docs/` |
| `examples/` | `examples/` |
| `ci.project.example.json` | `ci.project.example.json` |
| `RELEASE-MANIFEST.json` | `RELEASE-MANIFEST.json` |
| `README.md` | `README.md` |

The reusable workflow must be copied from the MotionDeck root `.github/workflows/shared-ci-reusable.yml` to the destination repository's `.github/workflows/reusable.yml`. Update its source checkout to the standalone repository and pin it to a release tag (for example `v0.1.0`), not `main`.

## Consumer contract

1. Commit a root-level `ci.project.json` conforming to `schemas/ci-project.schema.json`.
2. Add a caller workflow that invokes the reusable workflow from the versioned shared platform repository.
3. Register a dedicated runner with the `shared-ci` label before enabling dispatch.
4. Use protected branches and trusted code only on this runner.

## Smoke fixture

See `examples/smoke-project/README.md`. It includes a successful command fixture and an intentional exit-code-23 fixture. The expected results are documented but have not yet been executed.

## Release gates

Do not tag a stable release until:
- PowerShell 7 parser checks pass.
- Smoke success fixture produces a passed JSON/Markdown report.
- Expected-failure fixture exits non-zero and records exit code 23.
- Path traversal and invalid config fixtures are rejected before command execution.
- Workflow YAML is parsed and a manual run succeeds on the intended self-hosted runner.
- The release artifact contains no secrets or environment-specific paths.

The current `0.1.0` manifest is a bootstrap target, not a validated production release.
