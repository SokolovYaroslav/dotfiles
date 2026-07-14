# dotfiles

My terminal setup, managed with [chezmoi](https://chezmoi.io): zsh + oh-my-zsh, Claude Code
config (incl. the YouTrack MCP server), git, and 1Password-backed secrets. Public and
generalized — no secret values or internal vault/account names are committed; those are
collected by a one-time setup wizard and resolved from 1Password at runtime.

## Prerequisites

1. **1Password desktop app** — the only thing you must install by hand. Then, in
   **Settings → Developer**, enable **both** toggles (they are independent):
   - **Integrate with 1Password CLI** — lets `op` unlock via biometrics; without it the
     `claude`/`yt_*` secret lookups silently return nothing.
   - **Use the SSH agent** — populates the agent used for SSH and git commit signing.
     Enabling only the CLI toggle will leave you with *no keys* in the agent.
2. Everything else is installed by the bootstrap below: Homebrew (macOS only), the
   1Password CLI (`op`), Claude Code, `gh`, and the `central` proxy CLI. On Linux the
   `gh`/`op` installs use `apt` and will prompt for **sudo** once.

## Bootstrap a new machine

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply SokolovYaroslav/dotfiles
```

`chezmoi init` runs a short wizard:

| Prompt | Purpose |
| --- | --- |
| `opAccount` | Your 1Password account shorthand (e.g. `my.1password.com`) |
| `useOnePasswordSshAgent` | Route ssh-agent + git signing through 1Password (also writes `~/.ssh/config` with the agent's `IdentityAgent`) |
| `enableJbProxy` | Install + wire the JetBrains AI proxy: logs in and runs `central add claude-code`, which writes the per-machine proxy keys into `settings.json` itself so every `claude` launch routes through it |
| `installGh` | Install GitHub CLI and `gh auth login` |
| `enableMcp` | Register the YouTrack MCP server for Claude Code |
| `installSkills` | Pull global Claude Code skills into `~/.claude/skills` from my private `claude-skills` repo |

## Global Claude Code skills

Personal skills live in a **separate private repo** (they encode internal workflow, so they
don't belong in this public one). When `installSkills` is enabled, chezmoi pulls that repo into
`~/.claude/skills` as a git-repo external, cloned over SSH — so the 1Password SSH agent handles
auth. The repo URL is hardcoded in `.chezmoiexternal.toml`; that's harmless since cloning it
still requires access to the private repo.

## How secrets work

Items are looked up **by name** (`op item get '<item>' --account <opAccount> --fields
credential`), so no vault names are committed — only the account you enter in the wizard. This
assumes the item names are unique within that account.

- **On-demand shell functions** (`~/.zshenv`): `yt_token` / `yt_auth` (YouTrack token) and
  `anthropic_key` (Anthropic key) read from 1Password only when called — a plain shell start never
  triggers a 1Password unlock.
- **Self-authorizing MCP servers** (`run_onchange_after_40-mcp.sh.tmpl`): MCP servers that need a
  secret are registered so they resolve it themselves. The YouTrack server runs as a stdio bridge
  — `op run` resolves the token from 1Password (biometric) into the subprocess env, `sh` builds the
  `Authorization` header, and `mcp-proxy` (via `uvx`, no Node) forwards to the remote endpoint.
  Because Claude spawns this itself, it works no matter how `claude` was launched — terminal or the
  IDE Agent Workbench — with no launch-time env injection and no token on disk. Add a secret-bearing
  server by registering it the same way. (Proxy routing for the model API is handled transparently
  by the `apiKeyHelper` wire that `central add` baked into `settings.json`.)
- **Commit signing**: via the 1Password SSH agent (`op-ssh-sign`), no local private key.

## Machine-specific overrides

Anything host-only stays out of this repo: the managed shell files source unmanaged
`~/.zshrc.local`, `~/.zprofile.local`, and `~/.zshenv.local` if present. Put per-machine PATH
entries (e.g. TinyTeX, language frameworks) there.

## Daily use

```sh
chezmoi edit ~/.zshrc      # edit the source template
chezmoi diff               # preview changes
chezmoi apply              # apply to $HOME
chezmoi cd                 # jump to the source repo, then git push
```
