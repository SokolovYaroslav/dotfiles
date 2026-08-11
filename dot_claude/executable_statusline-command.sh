#!/usr/bin/env bash
# Claude Code statusline: session/monthly-left | model | context% | git branch
# The JetBrains quota segment self-disables if `central` is not installed.

input=$(cat)

# Ensure user-local + brew bins are visible even under a minimal (e.g. GUI) launch
# env, so `central`/`jq` resolve regardless of how Claude Code was started.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')

# Format session cost (.2f)
if [ -n "$cost" ]; then
  cost_str=$(printf '$%.2f' "$cost")
else
  cost_str='$-.--'
fi

# Format context usage
if [ -n "$used" ]; then
  ctx_str=$(printf 'ctx:%.0f%%' "$used")
else
  ctx_str='ctx:--%'
fi

# ---- JetBrains Central quota (cached, stale-while-revalidate) ----
CACHE="$HOME/.claude/.jb-quota-cache"  # epoch remaining
TTL=120       # refresh in the background once the cache is older than this
MAX_AGE=1800  # past this, mark the value stale (*) instead of pretending it's live

now=$(date +%s)

refresh_quota() {
  local out line r
  command -v central >/dev/null 2>&1 || return
  # Prefer --json: the field names are a stable contract, while the pretty
  # output is not -- a "Remaining: $1322.58" -> "Remaining: 1718.81 credits"
  # rewording is what silently froze this segment for a month.
  r=$(central quota --json 2>/dev/null \
      | jq -r '.tariffQuota.available // (.maxDollars|tonumber) - (.usedDollars|tonumber) // empty' \
        2>/dev/null)
  # Fall back to scraping, for a `central` too old to know --json. Accepts both
  # wordings, with or without thousands separators.
  if [ -z "$r" ] || [ "$r" = null ]; then
    out=$(central quota 2>/dev/null) || return
    line=$(printf '%s\n' "$out" | grep -E '^[[:space:]]*Remaining:' | head -1)
    [ -n "$line" ] || return
    r=$(printf '%s\n' "$line" | grep -oE '[0-9][0-9,]*(\.[0-9]+)?' | head -1 | tr -d ',')
  fi
  [ -n "$r" ] || return
  printf '%s %s\n' "$(date +%s)" "$r" > "$CACHE"
}

cache_age=""
if [ -f "$CACHE" ]; then
  ts=$(cut -d' ' -f1 "$CACHE" 2>/dev/null)
  case "$ts" in
    ''|*[!0-9]*) ;;
    *) cache_age=$((now - ts)) ;;
  esac
fi

if { [ -z "$cache_age" ] || [ "$cache_age" -ge "$TTL" ]; } \
   && command -v central >/dev/null 2>&1; then
  ( refresh_quota ) >/dev/null 2>&1 &
  disown 2>/dev/null
fi

jb_remaining=""
if [ -n "$cache_age" ]; then
  jb_remaining=$(cut -d' ' -f2 "$CACHE" 2>/dev/null)
fi

# Combine session cost with monthly remaining: {session .2f} / {left .0f}.
# A trailing * means the quota figure could not be refreshed and may be out of
# date -- without it a broken `central quota` parse looks like a live number.
if [ -n "$jb_remaining" ]; then
  stale=""
  [ "$cache_age" -gt "$MAX_AGE" ] && stale="*"
  cost_str=$(awk -v c="${cost:-0}" -v r="$jb_remaining" -v s="$stale" \
    'BEGIN{printf "$%.2f / $%.0f%s", c, r, s}')
fi

# Git branch (skip lock, suppress errors)
branch=""
if [ -n "$cwd" ] && [ -d "$cwd/.git" ] || git -C "${cwd:-.}" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "${cwd:-.}" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "${cwd:-.}" rev-parse --short HEAD 2>/dev/null)
fi

# Assemble
parts=("$cost_str")
[ -n "$model" ]      && parts+=("$model")
parts+=("$ctx_str")
[ -n "$branch" ] && parts+=("$branch")

printf '%s' "$(IFS=' | '; echo "${parts[*]}")"
