#!/usr/bin/env bash
# Cross-implementation test for the status line scripts.
# Verifies statusline.py and statusline.js produce byte-identical output to the
# bash reference (statusline.sh) across a range of payloads. Skips any runtime
# that isn't installed so it degrades gracefully on minimal machines.
#
# Usage: bash test.sh
set -u
cd "$(dirname "$0")"

have() { command -v "$1" >/dev/null 2>&1; }

# Runners for each implementation, guarded by availability.
run_sh() { bash statusline.sh; }
run_py() { python3 statusline.py; }
run_js() { node statusline.js; }

pass=0; fail=0

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

HOME_DIR="${HOME:-/home/user}"

check "full payload"       '{"workspace":{"current_dir":"'"$HOME_DIR"'/Documents/GitHub"},"model":{"display_name":"Opus 4.8"},"cost":{"total_cost_usd":0.1234,"total_duration_ms":3725000},"context_window":{"used_percentage":62.5},"rate_limits":{"five_hour":{"used_percentage":20},"seven_day":{"used_percentage":5}}}'
check "minimal cwd+model"  '{"cwd":"'"$HOME_DIR"'/x","model":{"display_name":"Sonnet 5"}}'
check "empty object"       '{}'
check "garbage input"      'not json at all'
check "empty string"       ''
check "high ctx (red)"     '{"context_window":{"used_percentage":91}}'
check "mid ctx (yellow)"   '{"context_window":{"used_percentage":55}}'
check "low ctx (green)"    '{"context_window":{"used_percentage":10}}'
check "cost only"          '{"cost":{"total_cost_usd":2.5}}'
check "duration <1h"       '{"cost":{"total_duration_ms":125000}}'
check "duration >1h"       '{"cost":{"total_duration_ms":7325000}}'
check "only 5h quota"      '{"rate_limits":{"five_hour":{"used_percentage":42}}}'
check "cwd not under home" '{"workspace":{"current_dir":"/opt/project"}}'

echo
echo "==== $pass passed, $fail failed ===="
[ "$fail" -eq 0 ]
