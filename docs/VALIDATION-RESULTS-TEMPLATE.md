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

- Parser validation: PASS / FAIL
- Success/report/stream/argument group: PASS / FAIL
- Expected child exit-code 23 group: PASS / FAIL
- Lexical traversal rejection: PASS / FAIL
- Absolute config and invalid schema rejection: PASS / FAIL
- Windows junction escape check: PASS / FAIL / NOT APPLICABLE
- Overall harness exit code:

## Console output

Paste the complete relevant console output here. Redact secrets and private machine paths before sharing.

## Notes

- Unexpected behavior:
- Follow-up issue:
- Reviewer: