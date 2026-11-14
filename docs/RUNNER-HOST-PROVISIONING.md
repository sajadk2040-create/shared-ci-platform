# Dedicated Shared CI account and directory preparation

The script scripts/Prepare-SharedCiRunnerHost.ps1 is a guarded, Windows-only provisioning helper. It creates only a new standard local account and a new dedicated directory. It does not register a GitHub runner, install a service, grant service logon rights, start processes, or modify any existing runner/account.

## Default plan

- Account: svc-shared-ci
- Directory: C:\GitHubRunners\shared-ci
- Directory ACL: protected from inheritance; Full Control for SYSTEM, local Administrators and the newly created service account.
- Password: entered interactively as a SecureString; minimum 16 characters; never placed in script arguments, output, files or logs.

The script refuses to continue if the account or target directory already exists, if the target is under the current user's profile, if the path does not match the dedicated drive layout, or if the parent-path preflight is unsafe. Before Apply can create anything, it inventories the target parent and every existing ancestor up to the volume root. It fails closed on reparse-point ancestors, inspection errors, or write-capable Allow ACEs for Everyone, Authenticated Users, BUILTIN Users, Interactive, or Network. The plan-only JSON includes this read-only assessment. This conservative check does not calculate effective access through nested group membership and is not a complete ACL security review. It never reuses the existing runner under a developer profile.

## Step 1 — review only

From PowerShell 7:

    pwsh -NoProfile -File scripts/Prepare-SharedCiRunnerHost.ps1

This prints the plan and makes no changes.

## Step 2 — explicitly authorize local provisioning

Run from an elevated PowerShell 7 session:

    pwsh -NoProfile -File scripts/Prepare-SharedCiRunnerHost.ps1 -Apply -ConfirmationText 'CREATE SHARED-CI SERVICE ACCOUNT AND ISOLATED DIRECTORY'

Windows may show the standard PowerShell ShouldProcess confirmation as an additional safeguard. Enter the account password only at the secure prompt. Do not pass it as a command-line argument or store it in a script/configuration file.

## Important safeguards and limitations

- Authoring this script did not create an account or directory on any machine.
- Apply plus the exact confirmation string and administrator elevation are required for changes.
- Existing local accounts and existing target directories are never modified or reused.
- If a failure occurs after a partial change, the script reports which resources this invocation created and deliberately does not perform an automatic rollback. Inspect locally before retrying.
- ACLs are set on the dedicated directory only. Parent directory creation, if needed, is separate and its ACL is not changed. Parent ancestors are inspected read-only; the script does not repair or change their ACLs.
- This is host preparation, not a security sandbox. A dedicated VM remains preferable.
- The account is not yet granted Log on as a service. That right, runner registration, service installation, runner labels and first workflow execution are separate approval/review gates.
- Do not use this account for interactive development. Do not run untrusted fork pull requests on a persistent privileged runner.
- Test the script on a disposable Windows VM before production use. PowerShell parser/runtime validation has not yet been performed for this new script.
