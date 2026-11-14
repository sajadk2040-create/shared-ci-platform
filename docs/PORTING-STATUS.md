# Standalone repository import status

**Status:** expanded eight-group Windows PowerShell 7.6.9 runtime smoke suite passed on `068a78027c74d023f13abf00122de14bb1d55461`. GitHub workflow validation, runner hardening and release gates remain outstanding.

## Imported from MotionDeck staging

The standalone repository contains the shared runner, schema, Node/Python/.NET presets, example project config, smoke success/failure fixtures, adapter contract, adoption guide and reusable workflow.

The platform's root layout is:
- `scripts/run.ps1`
- `schemas/ci-project.schema.json`
- `presets/`
- `docs/`
- `examples/smoke-project/`
- `.github/workflows/reusable.yml`

## Version policy

`RELEASE-MANIFEST.json` currently records version `0.1.0` as an imported bootstrap state. No `v0.1.0` release tag should be published until the release gates in `docs/REPOSITORY-BOOTSTRAP.md` pass.

The reusable workflow defaults its `platform-ref` input to `v0.1.0`; therefore consumer workflows must remain disabled until that tag exists and the runner is registered.

## Runtime validation history

- The initial Windows PowerShell 7.6.9 run of `tests/Invoke-RunnerSmokeTests.ps1` passed on the tested checkout. The harness returned exit code 0 and confirmed parser validation, successful execution/report capture, argument boundaries and redaction, child exit-code handling, lexical traversal rejection, Windows junction rejection, absolute config rejection, and invalid schema-version rejection.
- The run generated expected pass and intentional-failure reports in an isolated temporary directory; the intentional child failure was correctly recognized by the harness.
- The tested checkout was `f90d57348d261edaff0be74766d0911f6ab89bca`. This predates the latest timeout and concurrency changes; it is evidence only for the initial six-group harness, not for the new features.

## Latest engineering changes

- Added optional `timeoutSeconds` per step (integer 1–86400) to the runner and JSON Schema. A timeout attempts to kill the entire descendant process tree, records `timedOut: true`, and reports exit code 124.
- Run IDs now include millisecond time and a random suffix to avoid concurrent report/stream filename collisions.
- Extended the smoke harness with timeout + spawned-child termination and parallel-run artifact preservation tests.
- The expanded harness passed on Windows PowerShell 7.6.9 after the timeout, concurrency and cleanup changes; see the runtime validation update below.
- Raw process argument values remain excluded from runner JSON/log metadata; child stdout/stderr can still contain secrets and must be treated as sensitive.

## Remaining work

1. Review remaining process-tree termination limitations and workspace isolation.
2. Parse and review the reusable workflow and permissions.
3. Re-run local validation on the final release candidate.
4. Register a dedicated least-privilege self-hosted runner only after security review and user approval.
5. Publish `v0.1.0` only after all applicable gates pass.
6. Update MotionDeck's consumer workflow to call this repository at the released tag.

No GitHub Actions workflow was triggered, no self-hosted runner was registered, and no release tag was published.


## Runtime validation update — 2026-11-14

- Expanded the local Windows PowerShell 7 harness to eight groups, adding timeout handling, descendant-process termination and simultaneous-run report isolation.
- Runtime-tested on Windows with PowerShell 7.6.9. Final tested commit: `068a78027c74d023f13abf00122de14bb1d55461`.
- The complete harness printed `PASS: runner smoke tests (8 groups; includes timeout tree termination and parallel report isolation)` and exited with code 0.
- The timeout fixture verified `timedOut: true`, exit code 124, and that the spawned child process no longer remained running.
- The parallel fixture launched two runner processes into one report directory and verified two distinct run IDs and two preserved files for each JSON, Markdown, log, stdout and stderr artifact.
- Added defensive process-tree cleanup if process setup, waiting or stream collection fails after process start; reran the full harness after this change and it passed.
- JSON syntax parsing passed for the schema, example config, three presets and smoke-project config. Full Draft 2020-12 validation was not rerun on this host because the Python `jsonschema` package is not installed.
- This is local runner validation only. No GitHub Actions workflow was dispatched, no self-hosted runner was registered, and no release tag was created.


## Reusable workflow review — 2026-11-14

- Parsed the current `.github/workflows/reusable.yml` with PyYAML's BaseLoader; syntax parsing passed.
- Reviewed its least-privilege `contents: read` permission, separate caller/platform checkouts, `persist-credentials: false` on both checkouts, PowerShell 7 gate, and dedicated self-hosted Windows/X64/shared-ci labels.
- Corrected the runner invocation to force `-OutputDirectory artifacts/ci`, ensuring the artifact upload step targets the same directory even when a consumer config chooses a different local reportDirectory.
- No Actions workflow was dispatched. The workflow still needs a secured registered runner and a manual end-to-end run before release.
