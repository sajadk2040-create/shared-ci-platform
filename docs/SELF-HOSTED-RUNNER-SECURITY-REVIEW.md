# Self-hosted runner security review

Review date: 2026-11-14

## Decision

**Do not reuse the currently running runner installation for Shared CI Platform. Do not add the `shared-ci` label to it, reconfigure it, unregister it, or terminate its process as part of this work.** It is already registered to a different repository and is running interactively under the general development account. It must remain outside this project's execution path unless its owner separately authorizes a change.

No registration, workflow dispatch, service installation, account creation, permission change or process termination was performed during this review.

## Observed host state

The review was read-only and used Windows management metadata; runner credential files were not opened or copied.

- Host: Windows 11 Pro, x64.
- The configured runner is under `C:\Users\user\MotionDeckStudio\actions-runner\runner` (a nested runner root).
- Its non-secret `.runner` metadata identifies the target repository as `sajadk2040-create/nti-national-traffic-intelligence`, with runner name `BR-GHAZANFARI` and work folder `_work`.
- A `Runner.Listener.exe run` process was active and responding. Its parent chain shows it was launched by `run.cmd` from an interactive PowerShell/Explorer session on 2026-11-12.
- No Windows service matching the GitHub Actions runner was found. The listener is therefore not currently running as an installed Windows service.
- The listener process owner is `BR-GHAZANFARI\user`. That local account is a member of the machine's Administrators group, although the observed interactive process token was medium integrity.
- The configured runner root and its `_work` directory inherit Full Control for SYSTEM, BUILTIN\Administrators and the `user` account.
- A second copy of runner binaries exists at the outer `actions-runner\bin` path; the active configured instance is the nested `actions-runner\runner` root. Do not delete either tree until ownership and purpose are confirmed.
- Microsoft Defender Antivirus and real-time protection were enabled at the time of review.
- The Desktop Commander tool account had approximately 10% monthly remote-call capacity remaining; subsequent machine inspection should be batched and minimized.

The first shallow check looked only at the outer directory and therefore missed the nested `.runner` and credential markers. The recursive inspection corrected that conclusion: a configured runner does exist, but it belongs to another repository. Credential contents and registration tokens were not read.

## Why it is not suitable for this project

1. Its `.runner` metadata points to a different repository, not `shared-ci-platform`.
2. The active listener runs as the general `user` account, which is also an Administrators-group member and owns a broad development profile.
3. It is launched interactively rather than through a dedicated Windows service identity.
4. The runner's working directory is inside the existing user profile and is not isolated from the other development workspaces.
5. The current reusable workflow requires the dedicated `shared-ci` label; no evidence was gathered that this unrelated runner has that label.
6. Sharing this runner between unrelated repositories or privileged jobs would create cross-project and credential exposure risks.

## Target architecture for a new Shared CI runner

Provision a separate runner instance specifically for `sajadk2040-create/shared-ci-platform`:

- Dedicated path outside a developer profile, for example `C:\GitHubRunners\shared-ci`.
- Dedicated local standard account such as `svc-shared-ci`; not a member of Administrators and not used for interactive development.
- Grant that account only the rights needed to read/write its runner installation and isolated work directory. Keep SYSTEM and local Administrators as administrators of the host.
- Install and run the agent as a Windows service under the dedicated account, not LocalSystem and not the developer's account.
- Register it at repository scope for `sajadk2040-create/shared-ci-platform`, with labels `self-hosted`, `Windows`, `X64`, and `shared-ci`. Do not register an account-wide runner unless a separately reviewed runner group and repository allow-list are configured.
- Store registration credentials only in the interactive registration flow; never paste them into chat, source files, scripts, logs or command history.
- Use protected branches and trusted maintainers only. Do not run fork pull-request code or untrusted repository code on this persistent host.
- Do not expose deployment secrets to build/test jobs. Separate build and deployment runners if deployment is later added.
- Keep the runner and its work folder separate from MotionDeck source, personal files and other projects.
- Review service permissions, network egress, antivirus exclusions (prefer none), patching, and log retention before first job.
- Prefer disposable/ephemeral execution for untrusted code. A persistent runner is not a security sandbox; the command runner's path checks and timeout support do not constrain what a child process can access as its Windows account.

## Safe next sequence

1. Confirm the existing unrelated runner is intentionally retained by its owner; do not touch its process or credentials.
2. Decide whether the new Shared CI runner will be a separate local Windows account on this host or a dedicated VM. A dedicated VM provides stronger isolation.
3. Create the new standard account and runner directory using an administrator-controlled setup session. Keep the account password and registration token out of ChatGPT and shell history.
4. Apply and verify explicit NTFS ACLs before registration.
5. Register the new runner only to `shared-ci-platform` with the exact labels required by the reusable workflow.
6. Install it as a service under the dedicated account and verify service identity, startup type and online status.
7. Only then perform a manually approved end-to-end workflow test against a protected test branch, inspect artifact contents, and clean the test workspace.

## Release gate

The reusable workflow remains disabled for consumers and `v0.1.0` remains unpublished until the dedicated runner passes the above review and a manual end-to-end test. The current local PowerShell runner validation does not replace runner-host security validation.
