# Consumer template validation

Run from the Shared CI Platform repository root with PowerShell 7:

```powershell
pwsh -NoProfile -File tests/Invoke-ConsumerTemplateTests.ps1
```

The test is local and non-provisioning. It checks the starter JSON structure against the v1 contract, parses the sample PowerShell smoke script, and verifies that the workflow example uses exactly two matching immutable-SHA placeholders, manual dispatch, and read-only contents permission. It also rejects default push and pull-request triggers.

This is a focused structural test, not a full JSON Schema Draft 2020-12 validator or a GitHub Actions workflow execution. The template workflow is an example file and is not active until a consumer copies it to a workflow file and replaces both SHA placeholders with the same reviewed 40-character commit.
