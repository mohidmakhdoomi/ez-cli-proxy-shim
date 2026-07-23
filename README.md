# ez-cli-proxy-shim

Run Claude Code against a local [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
instance so `claude` talks to a Codex-backed model (e.g. `gpt-5.6-sol`) instead of
Anthropic's API — while keeping the ability to run the real binary untouched.

## What's in here

| File | Purpose |
| --- | --- |
| `install-cli-proxy.sh` | One-shot installer: builds CLIProxyAPI, does Codex OAuth, schedules it at boot, and installs the `claude` shim. |
| `claude` | A `claude` wrapper (shim) placed ahead of the real binary on `PATH`. |
| `config_proxy.yaml` | CLIProxyAPI server config (port `8317`, auth dir, etc.). |
| `settings_proxy.json` | Claude Code settings pointing at the local proxy. |

## Caveats

- **Tested only on Ubuntu 26.04 (WSL2), x86_64.** Untested elsewhere; the installer
  hardcodes the `go1.26.5.linux-amd64` download.
- **Uses `sudo`** to `rm -rf /usr/local/go` and to install Go into `/usr/local`.
- **Modifies `~/.profile` and your user crontab** (PATH exports + an `@reboot` entry).
- **Codex OAuth is interactive** — needs a browser and a Codex account.
- **Pinned versions** — Go, the CLIProxyAPI commit, and the repo-file downloads are
  pinned, so the copies here are informational and may drift from what the script fetches.
- **`REAL_CLAUDE` is machine-specific** — see [Configuration](#configuration).

These files work for me as is, **modify them to your needs**. e.g. you want to use API keys instead of OAuth, custom install directories, already have Go installed.

## Using the shim

The shim sits in front of the real Claude Code binary and adds a "how much shim?" ladder
of three flags (all stripped before running the real binary):

| Flag | Behaviour |
| --- | --- |
| _(none)_ / `--raw` | **Default.** Run the real Claude Code binary bare — no injected env or defaults. |
| `--shim` | Soft: inject proxy env vars + defaults, but your `--model` / `--settings` will override. |
| `--force-shim` | Forced: inject proxy env vars + defaults and ignore your `--model` / `--settings`. |

`--raw` always takes precedence; `--force-shim` beats `--shim`.

### Examples

```bash
claude -p "hi"                          # default: real binary, untouched
claude --shim -p "hi"                   # use the proxy (gpt-5.6-sol + proxy settings)
claude --shim --model gpt-5.5 -p "hi"   # use the proxy but keep your --model gpt-5.5
claude --force-shim --model gpt-5.5     # use the proxy, ignore --model gpt-5.5
```

When shimmed, the wrapper points Claude Code at `http://127.0.0.1:8317` and sets a few
`CLAUDE_CODE_*` env vars (see [Shim environment variables](#shim-environment-variables)).

## Configuration

The shim runs the real binary by absolute path so it doesn't recurse into itself. That
path is set by `REAL_CLAUDE` near the top of `claude`:

```bash
REAL_CLAUDE=/home/linuxbrew/.linuxbrew/bin/claude
```

This is machine-specific — Claude Code can be installed in other ways (npm, native
installer, etc.). Update `REAL_CLAUDE` to match your install; find it with
`which claude` (if the shim's `bin` dir is not in `PATH`, or use
`type -a claude`).

### Shim environment variables

When shimmed (`--shim` / `--force-shim`), the wrapper `exec`s the real binary through
`env` with a few `CLAUDE_CODE_*` vars set.

| Env var | Value | Purpose |
| --- | --- | --- |
| `CLAUDE_CODE_SUBAGENT_MODEL` | `$subagent_model` | Model used for subagents. Tracks the effective `--model` (defaults to `gpt-5.6-sol`; in `--shim` mode follows your own `--model` if you pass one). |
| `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT` | `1` | Always enable the reasoning-effort control. |
| `CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY` | `3` | Cap on concurrent tool calls. |
| `ENABLE_TOOL_SEARCH` | `false` | Disable deferred tool-search loading. |

To add your own env var or change a value, edit the `exec env … "$REAL_CLAUDE"`
block at the bottom of the `claude` shim.

The proxy connection itself (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`) is set via
`settings_proxy.json` rather than here — see `settings_proxy.json`.

### Install locations

The installer uses two directories, taken as optional positional args to
`install-cli-proxy.sh`:

```bash
./install-cli-proxy.sh [shim_dir] [proxy_dir]
```

| Arg | Default | Purpose |
| --- | --- | --- |
| `shim_dir` (`$1`) | `$(pwd)/bin` | Where the `claude` shim is installed (prepended to `PATH` via `~/.profile`). |
| `proxy_dir` (`$2`) | `$(pwd)` | Where CLIProxyAPI is cloned, built and referenced by the `@reboot` cron job. |

If you omit the args, both fall back to their `pwd`-based defaults, so **run the script
from the directory where you want these to live**. The `@reboot` cron entry hardcodes the
resolved `proxy_dir`, so moving it afterwards breaks auto-start.

## Install

> **No need to clone this repo.** Just copy the raw contents of
> `install-cli-proxy.sh` into a local file and run it — the script `wget`'s the
> other files it needs (shim, config, settings) straight from this repo.

```bash
./install-cli-proxy.sh [shim_dir] [proxy_dir]
```

This will:
- **Remove any existing Go install** at `/usr/local/go` (`sudo rm -rf`), then
  install the pinned Go there.
- Build CLIProxyAPI at a pinned commit into `$proxy_dir/CLIProxyAPI`.
- Run Codex OAuth login for the proxy.
- Add an `@reboot` cron job so the proxy starts automatically.
- Install the `claude` shim into `$shim_dir` (prepended to `PATH` via `~/.profile`).
- Copy `settings_proxy.json` into `~/.claude`.

**Note:** Reboot afterwards so CLIProxyAPI starts on its own.

## License

See [LICENSE](LICENSE).
