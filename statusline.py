#!/usr/bin/env python3
# Claude Code status line — cross-platform (macOS, Windows, Linux).
# Reads session JSON from stdin, prints one formatted line to stdout.
# Zero external dependencies: standard library only. No jq / awk / bash / node.

import json
import os
import sys

# --- ANSI colors ---
RESET = "\033[0m"
DIM = "\033[2m"
CYAN = "\033[36m"
YELLOW = "\033[33m"
GREEN = "\033[32m"
MAGENTA = "\033[35m"
BLUE = "\033[34m"
RED = "\033[31m"


def get(obj, dotted):
    """Safe nested lookup: get(obj, 'a.b.c')."""
    cur = obj
    for key in dotted.split("."):
        if isinstance(cur, dict) and key in cur:
            cur = cur[key]
        else:
            return None
    return cur


def pick(obj, *paths):
    """First non-null/non-empty value among several dotted paths."""
    for p in paths:
        v = get(obj, p)
        if v is not None and v != "":
            return v
    return None


def to_int(v):
    """Coerce to a rounded int, or None if not numeric."""
    if v is None or v == "":
        return None
    try:
        return round(float(v))
    except (TypeError, ValueError):
        return None


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
        if not isinstance(data, dict):
            data = {}
    except (ValueError, TypeError):
        data = {}

    cwd = pick(data, "workspace.current_dir", "cwd")
    model = pick(data, "model.display_name")
    total_cost = pick(data, "cost.total_cost_usd")
    duration_ms = pick(data, "cost.total_duration_ms")
    ctx_used = pick(data, "context_window.used_percentage")
    five_hr = pick(data, "rate_limits.five_hour.used_percentage")
    seven_day = pick(data, "rate_limits.seven_day.used_percentage")

    # Effort level is not in the stdin payload — read it from settings.json.
    # Key name has varied across versions; check project settings, then user.
    effort = None
    settings_paths = [
        os.path.join(os.getcwd(), ".claude", "settings.json"),
        os.path.join(os.path.expanduser("~"), ".claude", "settings.json"),
    ]
    for sp in settings_paths:
        try:
            with open(sp, "r", encoding="utf-8") as fh:
                s = json.load(fh)
            effort = s.get("effortLevel") or s.get("effort")
            if effort:
                break
        except (OSError, ValueError):
            pass  # missing or unparseable — ignore

    parts = []

    # Working directory (shorten home dir -> ~).
    if cwd:
        home = os.path.expanduser("~")
        shown = str(cwd)
        if home and shown.startswith(home):
            shown = "~" + shown[len(home):]
        parts.append(f"{CYAN}{shown}{RESET}")

    if model:
        parts.append(f"{BLUE}{model}{RESET}")
    if effort:
        parts.append(f"effort:{YELLOW}{effort}{RESET}")

    # Context used %  (green <50, yellow <80, red >=80)
    ctx_int = to_int(ctx_used)
    if ctx_int is not None:
        c = RED if ctx_int >= 80 else YELLOW if ctx_int >= 50 else GREEN
        parts.append(f"ctx:{c}{ctx_int}%{RESET}")

    # Rate limits
    quota = []
    p5 = to_int(five_hr)
    if p5 is not None:
        quota.append(f"5h:{MAGENTA}{p5}%{RESET}")
    p7 = to_int(seven_day)
    if p7 is not None:
        quota.append(f"7d:{MAGENTA}{p7}%{RESET}")
    if quota:
        parts.append("quota:" + " ".join(quota))

    # Cost
    if total_cost is not None:
        try:
            parts.append(f"cost:{GREEN}${float(total_cost):.4f}{RESET}")
        except (TypeError, ValueError):
            pass

    # Duration (from total_duration_ms)
    dsec = to_int(duration_ms)
    if dsec is not None:
        s = dsec // 1000
        h = s // 3600
        m = (s % 3600) // 60
        sec = s % 60
        duration_str = f"{h}h{m:02d}m" if h > 0 else f"{m}m{sec:02d}s"
        parts.append(f"{DIM}{duration_str}{RESET}")

    sys.stdout.write(" | ".join(parts))


if __name__ == "__main__":
    main()
