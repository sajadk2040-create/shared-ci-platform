# Standalone repository import status

**Status:** expanded eight-group Windows PowerShell 7.6.9 runtime smoke suite passed on `068a78027c74d023f13abf00122de14bb1d55461`. The five-group host-safety suite, the real Windows filesystem-link integration script and the smoke-project fixtures have now also executed and passed on the self-hosted runner via `.github/workflows/ci.yml` (runs `43765401540` and `43765594431`, PowerShell `7.6.9`, runner `2.338.2`); see `docs/CI-VALIDATION-RESULTS.md`. Runner service installation, branch protection and the release gates remain outstanding.

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

## GitHub Actions validation history

- **2026-11-15** — `.github/workflows/ci.yml` added and merged. First executions on the self-hosted runner
  `win-docker-01` (runner `2.338.2`, PowerShell `7.6.9`, Windows `10.0.26300`): core smoke suite, host-safety
  suite, real filesystem-link integration (actual junction created), smoke-project success fixture, smoke-project
  intentional-failure fixture (exit 23 asserted) and the consumer template tests all passed. Run `43765594431`
  on `main` and run `43765401540` on `ci/verify-self-check`, 12/12 steps each, 38 s each.
- The first attempt (run `43765317799`) failed because the smoke fixture was invoked from the repository root;
  `scripts/run.ps1` resolves project-relative paths against the current location, so the fixture has to run from
  its own directory. The workflow now does that and the defect is recorded in `docs/CI-VALIDATION-RESULTS.md`.
- The workflow intentionally has no `pull_request` trigger: the repository is public and a persistent
  self-hosted runner must not execute untrusted fork code.

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


## Runner host isolation audit — latest work, not yet runtime-validated (2026-11-14)

- Fixed isolation-audit root normalization to preserve Windows volume-root semantics using `DirectoryInfo.FullName`.
- Added `scripts/SharedCiAclRules.ps1` and delegated the audit's ACL decision to a normalized, reusable rule-assessment function.
- Added synthetic harness scenarios for the exact expected ACL, extra principal, Deny ACE, missing principal, wrong rights and inherited ACE. Added source checks for ancestor reparse-point traversal and volume-root preservation.
- Updated `docs/RUNNER-HOST-ISOLATION-AUDIT.md`, `docs/RUNNER-HOST-SAFETY-TESTS.md`, `docs/LOCAL-VALIDATION.md` and README.
- Latest relevant commits: audit path normalization `5d08841`; ACL helper `d217020`; audit integration `c3220c2`; harness `93d23e6`, `bc34121`, `1c4c4a5`; test guide `0bc15ca`.
- These latest changes have not been pulled or run on Windows. The previously recorded three-group host safety PASS applies only to the older harness. Do not report the current five-group suite as passed.
- No local account, password, ACL, runner registration or service was changed. The unrelated `nti-national-traffic-intelligence` runner remains out of scope and untouched. Do not publish `v0.1.0` yet.
