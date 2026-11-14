# Shared CI consumer starter

Copy this directory's contents into a new consumer repository, then customize the config and smoke script.

## Files

- `ci.project.example.json`: minimal Shared CI v1 configuration.
- `scripts/ci-smoke.ps1`: safe starter smoke check; replace/add project-specific checks.
- `.github/workflows/shared-ci.yml.example`: manual-only reusable workflow caller.

## Local validation

Install PowerShell 7 and clone this repository alongside or outside the consumer repository. From the consumer root:

```powershell
pwsh -NoProfile -File <path-to-shared-ci>/scripts/run.ps1 -ConfigPath ci.project.example.json
```

The command executes only the explicit steps in the config. It does not install dependencies or contact the network unless your own configured commands do so.

## Enable the GitHub workflow only after runner approval

1. Copy `.github/workflows/shared-ci.yml.example` to `.github/workflows/shared-ci.yml`.
2. Replace both `<REVIEWED_40_CHARACTER_COMMIT_SHA>` placeholders with the same reviewed immutable commit SHA from shared-ci-platform.
3. Review the config and smoke script.
4. Keep `workflow_dispatch` only until the dedicated self-hosted runner has passed isolation and runtime gates.
5. Do not add fork pull-request triggers or run untrusted code on a persistent self-hosted runner.

The workflow requires labels `self-hosted`, `Windows`, `X64`, and `shared-ci`. It is not intended for GitHub-hosted runners.
