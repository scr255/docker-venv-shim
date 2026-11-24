# docker-venv-shim

Docker-backed Python virtual environments for any repository.

`build_kernel.sh` builds a Docker image from `environments/<env>/` and creates a `.venv` whose `bin/python` runs inside that image; `python.sh` is the shim embedded into the generated `.venv`. Editors, terminals, and Jupyter kernels see a normal virtual environment — the interpreter and its dependencies live in the container.

Two Azure variants build on it:

- `build_kernel_azure_local.sh` — Personal in the Azure ML workspace (not visible to other users).
- `build_kernel_azure_remote.sh` — Shared in the Azure ML workspace (visible to other users).

## Contents

- [What you get](#what-you-get)
- [Setup](#setup)
- [Add to your workflow](#add-to-your-workflow)
  - [New repository](#new-repository)
  - [Existing repository](#existing-repository)
- [Usage](#usage)
- [Editors](#editors)

## What you get

- `.venv/bin/python` runs Python in the container as your host UID/GID, with the project bind-mounted at the same absolute path; `.venv/bin/activate` works in bash and zsh.
- Jupyter kernels work out of the box: `ipykernel` is added automatically and the shim handles the connection (including WSL host networking).
- Content-hashed image tags and a per-clone project ID: rebuilds happen only when the environment folder changes, and checkouts never collide; `--remove` cleans up by label.

## Setup

- Linux, macOS, or WSL with bash, Docker running and accessible, and `sha256sum` or `shasum` (`jq` optional).
- The Azure variants need only a `config.json` at the project root (copy `environments/config_azure_example.json`); the CLI and Python come from the container.

## Add to your workflow

The `sync-environments.yml` GitHub Action pulls the builders — and, optionally, the sample environments — from this repository into `environments/`, so you don't have to copy them by hand.

### New repository

On this page, click **Use this template → Create a new repository**. The workflow is inherited automatically.

### Existing repository

1. Add the workflow to your codebase:

   ```bash
   mkdir -p .github/workflows && curl -fL https://raw.githubusercontent.com/scr255/docker-venv-shim/main/.github/workflows/sync-environments.yml -o .github/workflows/sync-environments.yml
   ```

2. Commit and push to GitHub.

3. In the **Actions** tab, run **Sync environment builders from docker-venv-shim** ("Run workflow"). Besides the always-synced builders, you can tick the sample environment, the Azure builders, and/or the sample Azure environment. When it finishes, `environments/` is populated.

4. Pull the changes.

5. Continue with [Usage](#usage).

## Usage

```bash
chmod +x environments/build_kernel.sh   # grant execution
./environments/build_kernel.sh base     # build
.venv/bin/python script.py              # run python script
source .venv/bin/activate               # activate
```

Azure local — same options, plus `.venv/bin/az` sharing the host's Azure login:

```bash
./environments/build_kernel_azure_local.sh base_azure
.venv/bin/az login
```

Azure remote — publishes to an Azure ML workspace; run with the local Azure environment active. `--version N` sets the version (default 1); `--show` prints what would be published:

```bash
source .venv/bin/activate
./environments/build_kernel_azure_remote.sh base_azure --version 1
```

Options for `build_kernel.sh` and `build_kernel_azure_local.sh`:

| Option      | Effect                                                          |
| ----------- | --------------------------------------------------------------- |
| _(none)_    | Build if needed and make the environment active                 |
| `--rebuild` | Rebuild from scratch (`--pull --no-cache`)                      |
| `--remove`  | Remove the environment's containers, images, and `.venvs/<env>` |
| `--path`    | Print the interpreter path (for editor toolchain configuration) |

Multiple environments per project are supported; `.venv` points at the most recently built one. Add `.venv` and `.venvs/` to `.gitignore`.

## Zed editor

A simple way to automatically make Zed use the `.venv` is to edit `settings.json` (**Zed > Open Settings File**) and add the following configuration:

```json
  "terminal": {
    "shell": {
      "with_arguments": {
        "args": ["-l"],
        "program": "/bin/bash"
      }
    }
  }

```
