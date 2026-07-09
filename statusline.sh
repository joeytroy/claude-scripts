#!/usr/bin/env bash
# Claude Code status line (bash version — macOS & Linux; Windows via Git Bash).
# Requires: bash, jq. Reads session JSON from stdin, prints one line to stdout.
# For a zero-dependency cross-platform version, use statusline.js instead.
input=$(cat)

# jq helper -> prints the value, or empty string on null/missing/parse error.
j() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

cwd=$(j '.workspace.current_dir // .cwd')
model=$(j '.model.display_name')
total_cost=$(j '.cost.total_cost_usd')
duration_ms=$(j '.cost.total_duration_ms')
ctx_used=$(j '.context_window.used_percentage')
five_hr=$(j '.rate_limits.five_hour.used_percentage')
seven_day=$(j '.rate_limits.seven_day.used_percentage')

# Effort: the payload field .effort.level is the live session value (tracks
# mid-session /effort changes; absent when the model has no effort parameter).
# Fall back to the env var, then the effortLevel settings key, for older
# Claude Code versions without the field.
effort=$(j '.effort.level')
[ -z "$effort" ] && effort="${CLAUDE_CODE_EFFORT_LEVEL:-}"
if [ -z "$effort" ]; then
  for s in "$PWD/.claude/settings.json" "$HOME/.claude/settings.json"; do
    [ -f "$s" ] || continue
    effort=$(jq -r '.effortLevel // empty' "$s" 2>/dev/null)
    [ -n "$effort" ] && break
  done
fi

# --- Helpers ---
# Round a numeric string to an int; return non-zero if not numeric.
# Rounds half up (inputs are non-negative) to match the JS/Python versions —
# printf '%.0f' would round half-even and disagree on values like 62.5.
to_int() {
  case "$1" in ''|*[!0-9.]*) return 1 ;; esac
  awk -v v="$1" 'BEGIN{ printf "%d", v + 0.5 }'
}

# --- Session duration from total_duration_ms ---
duration_str=""
if dsec=$(to_int "${duration_ms%.*}"); then
  s=$(( dsec / 1000 ))
  h=$(( s / 3600 )); m=$(( (s % 3600) / 60 )); sec=$(( s % 60 ))
  if [ "$h" -gt 0 ]; then duration_str=$(printf '%dh%02dm' "$h" "$m")
  else duration_str=$(printf '%dm%02ds' "$m" "$sec"); fi
fi

# --- ANSI colors ---
reset=$'\033[0m'; dim=$'\033[2m'; cyan=$'\033[36m'; yellow=$'\033[33m'
green=$'\033[32m'; magenta=$'\033[35m'; blue=$'\033[34m'; red=$'\033[31m'

# --- Build segments ---
parts=()

# Working directory (shorten $HOME -> ~).  \~ so the tilde isn't re-expanded.
if [ -n "$cwd" ]; then
  parts+=( "${cyan}${cwd/#$HOME/\~}${reset}" )
fi

[ -n "$model" ]  && parts+=( "${blue}${model}${reset}" )
[ -n "$effort" ] && parts+=( "effort:${yellow}${effort}${reset}" )

# Context used %  (green <50, yellow <80, red >=80)
if ctx_int=$(to_int "$ctx_used"); then
  if   [ "$ctx_int" -ge 80 ]; then c="$red"
  elif [ "$ctx_int" -ge 50 ]; then c="$yellow"
  else c="$green"; fi
  parts+=( "ctx:${c}${ctx_int}%${reset}" )
fi

# Rate limits
quota=()
if p=$(to_int "$five_hr");   then quota+=( "5h:${magenta}${p}%${reset}" ); fi
if p=$(to_int "$seven_day"); then quota+=( "7d:${magenta}${p}%${reset}" ); fi
if [ "${#quota[@]}" -gt 0 ]; then
  parts+=( "quota:${quota[*]}" )   # joined by first char of IFS (space) below
fi

# Cost
if [ -n "$total_cost" ]; then
  cost_fmt=$(awk -v c="$total_cost" 'BEGIN{ printf "$%.4f", c }')
  parts+=( "cost:${green}${cost_fmt}${reset}" )
fi

# Duration
[ -n "$duration_str" ] && parts+=( "${dim}${duration_str}${reset}" )

# --- Print, segments separated by " | " ---
out=""
for p in "${parts[@]}"; do
  if [ -z "$out" ]; then out="$p"; else out="$out | $p"; fi
done
printf '%s' "$out"
