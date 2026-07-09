#!/usr/bin/env bash
# Cross-implementation test for the status line scripts.
# Verifies statusline.py and statusline.js produce byte-identical output to the
# bash reference (statusline.sh) across a range of payloads. Skips any runtime
# that isn't installed so it degrades gracefully on minimal machines.
#
# Runs each script with HOME pointed at an empty temp dir and the effort env
# var cleared, so results don't depend on the machine's real settings.json.
#
# Usage: bash test.sh
set -u
cd "$(dirname "$0")"
SCRIPT_DIR=$PWD

have() { command -v "$1" >/dev/null 2>&1; }

# Isolated fake home: no settings.json, so only payload fields affect output.
TESTHOME=$(mktemp -d)
trap 'rm -rf "$TESTHOME"' EXIT

# Runners for each implementation, guarded by availability. Each runs from the
# fake home with a scrubbed environment.
run_sh() { (cd "$TESTHOME" && HOME=$TESTHOME CLAUDE_CODE_EFFORT_LEVEL= bash "$SCRIPT_DIR/statusline.sh"); }
run_py() { (cd "$TESTHOME" && HOME=$TESTHOME CLAUDE_CODE_EFFORT_LEVEL= python3 "$SCRIPT_DIR/statusline.py"); }
run_js() { (cd "$TESTHOME" && HOME=$TESTHOME CLAUDE_CODE_EFFORT_LEVEL= node "$SCRIPT_DIR/statusline.js"); }

pass=0; fail=0

have python3 || echo "  SKIP  python3 not installed — statusline.py untested"
have node    || echo "  SKIP  node not installed — statusline.js untested"

check() {
  local name="$1" input="$2"
  local ref out
  ref=$(printf '%s' "$input" | run_sh)
  for impl in py js; do
    if [ "$impl" = py ] && ! have python3; then continue; fi
    if [ "$impl" = js ] && ! have node;    then continue; fi
    out=$(printf '%s' "$input" | "run_$impl")
    if [ "$out" = "$ref" ]; then
      printf '  PASS  %-18s (%s)\n' "$name" "$impl"; pass=$((pass+1))
    else
      printf '  FAIL  %-18s (%s)\n' "$name" "$impl"; fail=$((fail+1))
      printf '    ref: [%s]\n' "$(printf '%s' "$ref" | cat -v)"
      printf '    %s : [%s]\n' "$impl" "$(printf '%s' "$out" | cat -v)"
    fi
  done
}

# expect: assert the bash reference renders an exact plain-text line (colors
# stripped), pinning behavior rather than just cross-impl agreement.
expect() {
  local name="$1" input="$2" want="$3"
  local got
  got=$(printf '%s' "$input" | run_sh | sed $'s/\033\\[[0-9;]*m//g')
  if [ "$got" = "$want" ]; then
    printf '  PASS  %-18s (ref)\n' "$name"; pass=$((pass+1))
  else
    printf '  FAIL  %-18s (ref)\n' "$name"; fail=$((fail+1))
    printf '    want: [%s]\n' "$want"
    printf '    got : [%s]\n' "$got"
  fi
}

HOME_DIR=$TESTHOME

check "full payload"       '{"workspace":{"current_dir":"'"$HOME_DIR"'/Documents/GitHub"},"model":{"display_name":"Opus 4.8"},"effort":{"level":"high"},"cost":{"total_cost_usd":0.1234,"total_duration_ms":3725000},"context_window":{"used_percentage":62.5},"rate_limits":{"five_hour":{"used_percentage":20},"seven_day":{"used_percentage":5}}}'
check "minimal cwd+model"  '{"cwd":"'"$HOME_DIR"'/x","model":{"display_name":"Sonnet 5"}}'
check "empty object"       '{}'
check "garbage input"      'not json at all'
check "empty string"       ''
check "effort only"        '{"effort":{"level":"max"}}'
check "effort xhigh"       '{"model":{"display_name":"Fable 5"},"effort":{"level":"xhigh"}}'
check "high ctx (red)"     '{"context_window":{"used_percentage":91}}'
check "mid ctx (yellow)"   '{"context_window":{"used_percentage":55}}'
check "low ctx (green)"    '{"context_window":{"used_percentage":10}}'
check "ctx rounds .5 up"   '{"context_window":{"used_percentage":49.5}}'
check "cost only"          '{"cost":{"total_cost_usd":2.5}}'
check "duration <1h"       '{"cost":{"total_duration_ms":125000}}'
check "duration >1h"       '{"cost":{"total_duration_ms":7325000}}'
check "only 5h quota"      '{"rate_limits":{"five_hour":{"used_percentage":42}}}'
check "cwd not under home" '{"workspace":{"current_dir":"/opt/project"}}'

expect "effort rendering"  '{"model":{"display_name":"Opus 4.8"},"effort":{"level":"high"}}' 'Opus 4.8 | effort:high'
expect "half-up rounding"  '{"context_window":{"used_percentage":62.5}}' 'ctx:63%'

echo
echo "==== $pass passed, $fail failed ===="
[ "$fail" -eq 0 ]
