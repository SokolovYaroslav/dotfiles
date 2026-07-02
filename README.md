# dotfiles

My terminal setup, managed with [chezmoi](https://chezmoi.io): zsh + oh-my-zsh, Claude Code
config (incl. the YouTrack MCP server), git, and 1Password-backed secrets. Public and
generalized — no secret values or internal vault/account names are committed; those are
collected by a one-time setup wizard and resolved from 1Password at runtime.

## Prerequisites

1. **1Password CLI** — install and sign in first; all secret resolution depends on it:
   ```sh
   brew install 1password-cli   # or your platform's package
   op signin
   ```
2. The 1Password desktop app (for the SSH agent + commit signing) if you opt into those.

## Bootstrap a new machine

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <your-github-username>/dotfiles
```

`chezmoi init` runs a short wizard:

| Prompt | Purpose |
| --- | --- |
| `opAccount` | Your 1Password account shorthand (e.g. `my.1password.com`) |
| `opVaultYT` | Vault holding the YouTrack token (item `YT Token`) |
| `opVaultAnthropic` | Vault holding the Anthropic key (item `Anthropic API key dev`) |
| `useOnePasswordSshAgent` | Route ssh-agent + git signing through 1Password |
| `enableJbProxy` | Install + wire the JetBrains AI proxy: logs in and runs `jbcentral add claude-code`, which writes the per-machine proxy keys itself |
| `installGh` | Install GitHub CLI and `gh auth login` |
| `enableMcp` | Register the YouTrack MCP server for Claude Code |

## How secrets work

- **On-demand shell functions** (`~/.zshenv`): `yt_token` / `yt_auth` read the YouTrack token
  from 1Password only when called — a plain shell start never triggers a 1Password unlock.
- **`claude()` wrapper** (`~/.zshenv`): when you launch Claude Code, it reads every entry in the
  `CLAUDE_SECRETS` map from 1Password and injects them into Claude's subprocess env. The MCP
  config references `${YOUTRACK_TOKEN}` — so no token is ever written to disk. Add a new secret by
  appending one line to `CLAUDE_SECRETS`.
- **`op://` templates** (`~/.config/op/secrets.env`): consumed via `op run --env-file`.
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
