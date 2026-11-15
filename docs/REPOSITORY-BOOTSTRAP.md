# Standalone repository bootstrap

Target repository: `sajadk2040-create/shared-ci-platform`.

The standalone repository has been created and populated. Its root contains the PowerShell runner, schema, presets, examples, documentation, reusable workflow and MIT license.

## Consumer contract

1. Commit a root-level `ci.project.json` conforming to `schemas/ci-project.schema.json`.
2. Add a caller workflow that invokes the reusable workflow from a reviewed immutable commit SHA.
3. Register a dedicated runner in the consumer repository scope, or use an organization runner group restricted to approved consumer repositories. A runner registered only to this platform repository is not automatically available to consumer repositories.
4. Use a protected caller branch and trusted code only on this persistent runner.
5. Keep the report output under `artifacts/ci` for the reusable workflow artifact upload.

## Local runtime validation

See [Local validation guide](LOCAL-VALIDATION.md). The expanded eight-group smoke harness passed on Windows / PowerShell 7.6.9 at commit `068a78027c74d023f13abf00122de14bb1d55461`. It covers parser validation, success/failure behavior, stream/report capture, argument preservation/redaction, lexical and junction path rejection, invalid config, timeout with spawned-child termination, and parallel report isolation.

The harness is a local runner test. It does not validate the GitHub reusable workflow, runner service configuration, permissions on a long-lived runner or deployment behavior.

## Reusable workflow design

- The workflow checks out the caller project and platform source into separate directories.
- Both checkouts disable persisted Git credentials.
- Workflow permissions are limited to `contents: read`.
- The reusable job runs only for manual dispatches from a protected caller ref.
- The job requires a dedicated self-hosted Windows/X64 runner with the `shared-ci` label.
- The platform ref must be a full 40-character hexadecimal commit SHA.
- Third-party actions are pinned to full commit SHAs.
- The runner's output directory is explicitly set to `artifacts/ci`, matching the artifact upload path.
- Report artifacts are retained for three days and must still be reviewed for sensitive output.
- Do not run untrusted fork pull-request code on a privileged self-hosted runner.

## Release gates

Do not publish `v0.1.0` until all of the following are complete:
- The expanded local PowerShell 7 smoke harness passes on the release candidate.
- The reusable workflow YAML is parsed and reviewed, including the manual/protected-ref conditions.
- A dedicated least-privilege self-hosted runner is provisioned in the correct consumer scope, isolated and security-reviewed.
- A manual workflow run succeeds on that runner using a reviewed platform commit.
- Artifact upload is verified and reviewed for secret leakage.
- The release artifact contains no secrets or machine-specific paths.
- MotionDeck's consumer config/workflow is reviewed and uses the versioned platform reference.

The current `0.1.0` manifest remains a bootstrap target, not a published production release. No release tag exists until these gates pass.
