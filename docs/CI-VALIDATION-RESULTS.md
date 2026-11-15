# CI validation results — first green execution

**Status:** the platform's own validation suites executed end-to-end on the dedicated self-hosted Windows runner and passed.
Date: **2026-11-15**.

## Runner

| Item | Value |
|---|---|
| Runner name | `win-docker-01` |
| Runner version | `2.338.2` |
| Labels | `self-hosted`, `Windows`, `X64`, `shared-ci` |
| PowerShell | `7.6.9` (Core) |
| OS | `Microsoft Windows 10.0.26300` (Win32NT, x64) |
| Workspace | `C:\GitHubRunners\shared-ci\_work\shared-ci-platform\shared-ci-platform` |

## Workflow

`.github/workflows/ci.yml` — "Shared CI (self-check)". Triggers: `workflow_dispatch` and `push` to `main` and `ci/**`.
It deliberately has **no `pull_request` trigger** and additionally guards with
`if: github.event.repository.full_name == github.repository`, because the repository is public and a
self-hosted runner executes repository code with the rights of its host account.

Permissions are limited to `contents: read` and checkout runs with `persist-credentials: false`.

## Runs

| Run | Ref | Result | Duration |
|---|---|---|---|
| [43765594431](https://github.com/sajadk2040-create/shared-ci-platform/actions/runs/43765594431) | `main` | **success** — 12/12 steps | 38 s |
| [43765401540](https://github.com/sajadk2040-create/shared-ci-platform/actions/runs/43765401540) | `ci/verify-self-check` | **success** — 12/12 steps | 38 s |
| [43765317799](https://github.com/sajadk2040-create/shared-ci-platform/actions/runs/43765317799) | `ci/verify-self-check` | failure — invalid invocation path (fixed, see below) | 38 s |

## Suites executed

| Step | Suite | Required | Result |
|---|---|---|---|
| 1 | PowerShell 7 version gate | yes | passed |
| 2 | `tests/Invoke-RunnerSmokeTests.ps1` (eight-group core suite) | yes | passed |
| 3 | `tests/Invoke-RunnerHostSafetyTests.ps1` (five-group host-safety suite) | yes | passed |
| 4 | `tests/Invoke-RunnerFilesystemLinkIntegrationTests.ps1 -EnableFilesystemLinkTests` (real Windows junction) | opt-in | passed |
| 5 | `examples/smoke-project/ci.project.json` — success fixture | yes | passed |
| 6 | `examples/smoke-project/ci.project.expected-failure.json` — must exit non-zero | yes | passed (exit 23 observed) |
| 7 | `tests/Invoke-ConsumerTemplateTests.ps1` | opt-in | passed |
| 8 | Report artifact upload | — | passed |

## What this changes

Two items previously recorded as outstanding are now executed evidence:

1. The **five-group host-safety suite** ran on Windows and passed.
2. The **opt-in real-filesystem-link integration script** created a real junction on Windows and passed.

The runner was also exercised with concurrent-safe run IDs and per-step timeouts inside the smoke suite,
which cover the timeout and report-isolation work noted in `docs/PORTING-STATUS.md`.

## Invocation defect found and fixed

The first workflow version invoked the smoke fixture from the repository root:

```powershell
pwsh -NoProfile -File scripts/run.ps1 -ConfigPath examples/smoke-project/ci.project.json
```

`scripts/run.ps1` resolves project-relative paths against the current location, so the step's
`checks/pass.ps1` could not be found and the run failed with status `failed`. The fixture must be run
from its own directory, as `examples/smoke-project/README.md` already specifies:

```powershell
Set-Location examples/smoke-project
pwsh -NoProfile -File ../../scripts/run.ps1 -ConfigPath ci.project.json
```

The workflow now does exactly that and additionally asserts that the intentional-failure fixture exits
non-zero.

## Still outstanding

1. The runner currently starts from `run.cmd` (interactive window or an `AtStartup` scheduled task), not from a
   Windows service. Installing it as a service requires `config.cmd remove` followed by a reconfigure with
   `--runasservice`, because the flag is only accepted at configuration time.
2. `main` has no branch protection: no required status check, no review requirement, no force-push block.
3. The stacked security pull requests (`#1`, `#2`, `#5`, `#6`) are still draft and unmerged.
4. No `v0.1.0` tag exists, so consumers cannot pin `platform-ref`.
5. `actions/checkout@v4` and `actions/upload-artifact@v4` emit a Node.js 20 deprecation warning; a future
   bump to `@v5` is recommended.
6. The runner executes as the installing account or `SYSTEM`; the dedicated `svc-shared-ci` service account
   path in `docs/RUNNER-HOST-PROVISIONING.md` has not been applied.
