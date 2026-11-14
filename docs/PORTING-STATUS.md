# Standalone repository import status

**Status:** initial Windows PowerShell 7 runtime smoke suite passed; expanded timeout and concurrency regression coverage added and pending execution. Release remains blocked.

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
- These new changes are committed but **have not yet been runtime-tested**. Run the expanded harness on Windows PowerShell 7 before considering release.
- Raw process argument values remain excluded from runner JSON/log metadata; child stdout/stderr can still contain secrets and must be treated as sensitive.

## Remaining work

1. Execute the expanded smoke harness on Windows PowerShell 7 and review all output.
2. Review runner exception cleanup, process-tree termination limitations and workspace isolation.
3. Parse and review the reusable workflow and permissions.
4. Register a dedicated least-privilege self-hosted runner only after security review and user approval.
5. Publish `v0.1.0` only after all applicable gates pass.
6. Update MotionDeck's consumer workflow to call this repository at the released tag.

No GitHub Actions workflow was triggered, no self-hosted runner was registered, and no release tag was published.
