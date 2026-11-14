# Local validation evidence

Copy this file to a private/local location when running the validation procedure. Do not commit machine-specific paths, usernames, tokens, environment dumps or secrets.

## Environment

- Date/time (with timezone):
- Windows edition/build:
- PowerShell version (`$PSVersionTable.PSVersion`):
- Platform repository commit SHA tested:
- PowerShell executable path (optional; redact user-specific segments):

## Command

```powershell
pwsh -NoProfile -File tests/Invoke-RunnerSmokeTests.ps1
```

## Results

- PowerShell parser validation: PASS / FAIL
- Success/report/stream/argument group: PASS / FAIL
- Expected child exit-code 23 group: PASS / FAIL
- Lexical traversal and absolute config rejection: PASS / FAIL
- Invalid schema version rejection: PASS / FAIL
- Windows junction escape check: PASS / FAIL / NOT APPLICABLE
- Timeout and descendant-process termination: PASS / FAIL
- Concurrent run ID and artifact isolation: PASS / FAIL
- Overall harness exit code:

## Console output

Paste the complete relevant console output here. Redact secrets and private machine paths before sharing.

## Notes

- Unexpected behavior:
- Follow-up issue:
- Reviewer:

## Scope boundary

A local harness pass does not validate the reusable GitHub workflow, self-hosted runner service account, GitHub control plane, artifact permissions or deployment behavior. Record those as separate release gates.
