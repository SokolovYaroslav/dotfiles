#!/usr/bin/env bash
# Claude Code statusline: session/monthly-left | model | context% | git branch
# The JetBrains quota segment self-disables if `jbcentral` is not installed.

input=$(cat)

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
CACHE="$HOME/.claude/.jb-quota-cache"  # epoch used remaining
TTL=120

now=$(date +%s)

refresh_quota() {
  local out r
  command -v jbcentral >/dev/null 2>&1 || return
  out=$(jbcentral quota 2>/dev/null) || return
  r=$(printf '%s\n' "$out" | grep -oE 'Remaining:[[:space:]]*\$[0-9.]+' | grep -oE '[0-9.]+' | head -1)
  [ -n "$r" ] && printf '%s %s\n' "$(date +%s)" "$r" > "$CACHE"
}

need_refresh=1
if [ -f "$CACHE" ]; then
  ts=$(cut -d' ' -f1 "$CACHE" 2>/dev/null)
  [ -n "$ts" ] && [ $((now - ts)) -lt "$TTL" ] && need_refresh=0
fi
if [ "$need_refresh" = 1 ] && command -v jbcentral >/dev/null 2>&1; then
  ( refresh_quota ) >/dev/null 2>&1 &
  disown 2>/dev/null
fi

jb_remaining=""
if [ -f "$CACHE" ]; then
  jb_remaining=$(cut -d' ' -f2 "$CACHE" 2>/dev/null)
fi

# Combine session cost with monthly remaining: {session .2f} / {left .0f}
if [ -n "$jb_remaining" ]; then
  cost_str=$(awk -v c="${cost:-0}" -v r="$jb_remaining" \
    'BEGIN{printf "$%.2f / $%.0f", c, r}')
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
