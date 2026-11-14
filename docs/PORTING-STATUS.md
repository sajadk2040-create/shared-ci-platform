# Standalone repository import status

**Status:** source import completed; runtime validation and release are pending.

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

## Remaining work

1. Run PowerShell 7 parser validation on `scripts/run.ps1`.
2. Run smoke success fixture and verify all reports.
3. Run intentional failure fixture; verify non-zero runner exit and recorded step exit code 23.
4. Add and run invalid-config and path traversal negative tests.
5. Parse the reusable workflow YAML and review permissions/checkout behavior.
6. Decide public/private access and register a dedicated least-privilege self-hosted runner.
7. Publish `v0.1.0` only after all applicable gates pass.
8. Update MotionDeck's consumer workflow to call this repository at the released tag.

No workflow was triggered and no PowerShell runtime test is claimed by this import.
