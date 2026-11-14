# Standalone repository import status

**Status:** source import completed; MIT license added; workflow input handling hardened; runtime validation and release are pending.

## Imported from MotionDeck staging

The standalone repository now contains the shared runner, schema, Node/Python/.NET presets, example project config, smoke success/failure fixtures, adapter contract, adoption guide and reusable workflow.

The platform's root layout is now:
- `scripts/run.ps1`
- `schemas/ci-project.schema.json`
- `presets/`
- `docs/`
- `examples/smoke-project/`
- `.github/workflows/reusable.yml`

## Version policy

`RELEASE-MANIFEST.json` currently records version `0.1.0` as an imported bootstrap state. No `v0.1.0` release tag should be published until the release gates in `docs/REPOSITORY-BOOTSTRAP.md` pass.

The reusable workflow defaults its `platform-ref` input to `v0.1.0`; therefore consumer workflows must remain disabled until that tag exists and the runner is registered.

## Completed follow-up

- Added the MIT License at repository root and linked it from README.
- Hardened the reusable workflow: the caller-provided config path is now passed through an environment variable instead of interpolated directly into a PowerShell command string.

## Smoke test harness added

`tests/Invoke-RunnerSmokeTests.ps1` is a self-contained PowerShell 7 harness. It creates an isolated temporary project and exercises six groups: successful execution and report capture; preservation of arguments containing spaces/quotes; intentional child exit code 23 and runner failure status; rejection of lexical working-directory traversal; rejection of Windows junction traversal; rejection of absolute config paths; and rejection of an unsupported schema version before any configured command executes. The harness is authored but has **not** been executed because this environment has no PowerShell runtime and remote Desktop Commander allowance is nearly exhausted. On Windows it also creates a directory junction to an outside folder and verifies that the runner rejects it; symlink/reparse-point handling still requires runtime validation.

## Latest local-validation preparation

- Added `docs/LOCAL-VALIDATION.md` with a reproducible Windows PowerShell 7 procedure that does not use GitHub Actions or a registered runner.
- Extended `tests/Invoke-RunnerSmokeTests.ps1` to parse the runner source with the PowerShell language parser before executing smoke tests.
- Updated the root README to link the local validation guide.
- These are authored changes only. The harness has still **not** been executed; no runtime pass is claimed.

## Remaining work

1. Run `pwsh -NoProfile -File tests/Invoke-RunnerSmokeTests.ps1` on Windows PowerShell 7 and capture complete output, including the junction case.
2. Review the reparse-point checks for time-of-check/time-of-use races; the current checks reject existing reparse-point components but do not eliminate concurrent filesystem replacement.
3. Parse the reusable workflow YAML and review permissions/checkout behavior.
4. Register a dedicated least-privilege self-hosted runner only after security review and user approval.
5. Publish `v0.1.0` only after all applicable gates pass.
6. Update MotionDeck's consumer workflow to call this repository at the released tag.

No workflow was triggered and no PowerShell runtime test is claimed by this import.
