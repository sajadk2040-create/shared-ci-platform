# Dedicated Shared CI account and directory preparation

The script scripts/Prepare-SharedCiRunnerHost.ps1 is a guarded, Windows-only provisioning helper. It creates only a new standard local account and a new dedicated directory. It does not register a GitHub runner, install a service, grant service logon rights, start processes, or modify any existing runner/account.

## Default plan

- Account: svc-shared-ci
- Directory: C:\GitHubRunners\shared-ci
- Directory ACL: protected from inheritance; Full Control for SYSTEM, local Administrators and the newly created service account.
- Password: entered interactively as a SecureString; minimum 16 characters; never placed in script arguments, output, files or logs.

The script refuses to continue if the account already exists, if an existing target path is not a directory or fails the exact inherited SYSTEM/Administrators ACL and reparse-point checks, if the target is under the current user's profile, if the path does not match the dedicated drive layout, or if the parent-path preflight is unsafe. A pre-existing target directory is accepted only as a safely ACL-verified partial directory; it is not blindly reused. Before Apply can create anything, the dedicated parent directory must already exist. The script never creates that parent automatically. The parent must have exactly two explicit, inheritable Full Control Allow ACEs: SYSTEM and local Administrators, with inheritance protected. It rejects any broad-principal write ACE on that parent. It walks every ancestor to the volume root to reject reparse points, inspection errors, and broad-principal `DeleteSubdirectoriesAndFiles` rights that could remove the secured parent. Broad create-directory rights on an ancestor (including the drive root) do not by themselves invalidate an already-existing protected child directory. The plan-only JSON includes this read-only assessment. The check does not calculate effective access through nested group membership and is not a complete ACL security review. It never reuses the existing runner under a developer profile.

## Step 1 — administrator prepares the parent once

From an elevated PowerShell session, create `C:\GitHubRunners` if it does not exist, then protect its ACL and grant Full Control only to SYSTEM and local Administrators. For example:

    New-Item -ItemType Directory -Path 'C:\GitHubRunners' -Force | Out-Null
    icacls 'C:\GitHubRunners' /inheritance:r
    icacls 'C:\GitHubRunners' /grant:r '*S-1-5-18:(OI)(CI)(F)' '*S-1-5-32-544:(OI)(CI)(F)'

Review the resulting ACL locally before continuing. These commands change only the dedicated parent directory; do not apply them to `C:\` or to the unrelated existing runner.

## Step 2 — review only

From PowerShell 7:

    pwsh -NoProfile -File scripts/Prepare-SharedCiRunnerHost.ps1

This prints the plan and makes no changes.

## Step 3 — explicitly authorize local provisioning

Run from an elevated PowerShell 7 session:

    pwsh -NoProfile -File scripts/Prepare-SharedCiRunnerHost.ps1 -Apply -ConfirmationText 'CREATE SHARED-CI SERVICE ACCOUNT AND ISOLATED DIRECTORY'

Windows may show the standard PowerShell ShouldProcess confirmation as an additional safeguard. Enter the account password only at the secure prompt. Do not pass it as a command-line argument or store it in a script/configuration file.

## Important safeguards and limitations

- Authoring this script did not create an account or directory on any machine.
- Apply plus the exact confirmation string and administrator elevation are required for changes.
- Existing local accounts and existing target directories are never modified or reused.
- If a failure occurs after a partial change, the script reports which resources this invocation created and deliberately does not perform an automatic rollback. Inspect locally before retrying.
- The parent directory must be prepared manually before provisioning. The script refuses to create it or change its ACL. The script applies a separate protected ACL to the new runner directory only; all parent ancestors are inspected read-only.
- This is host preparation, not a security sandbox. A dedicated VM remains preferable.
- The account is not yet granted Log on as a service. That right, runner registration, service installation, runner labels and first workflow execution are separate approval/review gates.
- Do not use this account for interactive development. Do not run untrusted fork pull requests on a persistent privileged runner.
- The plan-only path and host-safety source guards have been exercised on Windows PowerShell 7.6.10 x64. Apply mode, account creation, ACL mutation, and partial-failure recovery have deliberately not been exercised. Test those separately on a disposable Windows VM before any production use.
