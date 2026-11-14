# Shared CI adapter contract v1

The platform core remains a small ordered process runner. Runtime-specific behavior belongs in project presets/adapters, not in the core engine.

## Supported starter presets

- `presets/node.json`: npm-based projects with a committed lockfile; uses `npm ci`.
- `presets/python.json`: Python projects with `requirements.txt`; projects should pin dependencies or use a lockfile-backed requirements export.
- `presets/dotnet.json`: .NET projects using `dotnet restore/build/test`.

These are templates, not universal assumptions. Copy and tailor them to the actual scripts and project layout. For monorepos, set each step's `workingDirectory` to the relevant package.

## Core process contract

Each step declares:
- `name`: report label.
- `command`: executable resolved by the runner environment.
- `args`: argument array; never concatenate a shell command string.
- `workingDirectory`: path relative to the project root.
- `continueOnError`: optional, defaults to false.
- `timeoutSeconds`: optional integer from 1 to 86400. When omitted, the runner waits without a time limit. On timeout, it attempts to terminate the child process and its descendant process tree, records `timedOut: true`, and uses exit code 124.

The runner records start/end time, duration, exit code, stdout/stderr filenames, status and argument count. Each run receives a timestamp plus a random identifier so concurrent runs do not overwrite one another's report or stream files. Raw argument values are intentionally excluded from logs and JSON reports because arguments may contain credentials. Any failed step without `continueOnError: true` makes the overall run fail.

## Reproducibility

- Node: commit `package-lock.json` and use `npm ci`.
- Python: pin dependencies and preferably commit a lock/constraints file; change the preset install command to match the chosen manager.
- .NET: commit project/solution files and pin SDK with `global.json` where reproducibility requires it.
- Do not install tools globally from project scripts.
- Never pass secrets as literal command arguments; use the runner host's protected secret/environment mechanism when a trusted workflow needs credentials. The runner does not persist raw argument values, but operating-system process inspection may still expose arguments while a child is running.
- Child stdout/stderr are captured verbatim and may contain secrets if the child prints them. Do not print credentials, and do not upload reports from jobs that may emit secret material. Treat artifacts as sensitive.
- Network access occurs only if a configured step explicitly invokes a package manager or downloader; the core runner itself does not access the network.

## Security

Treat project configuration and commands as executable code. Only run trusted branches/projects on shared self-hosted machines. Use isolated workspaces and a low-privilege runner account. Do not share a runner between untrusted repositories and privileged deployment jobs. Timeout tree termination is best-effort and should not be treated as a substitute for OS-level job isolation and resource controls.
