# claude-scripts

Utilities for [Claude Code](https://claude.com/claude-code).

## Status line

A custom status line showing working directory, model, reasoning effort,
context usage, rate-limit quotas, session cost, and elapsed time:

```
~/Documents/GitHub | Opus 4.8 | effort:high | ctx:63% | quota:5h:20% 7d:5% | cost:$0.1234 | 1h02m
```

### Which file to use

There is **no single script that runs on stock Windows + macOS + Linux with
zero assumptions** — Windows and Unix share no common shell, and `jq` / `node`
are not installed by default anywhere. So you pick the one runtime you already
have. All three implementations render identical output.

| File            | Runtime  | Extra deps | Works on                              |
| --------------- | -------- | ---------- | ------------------------------------- |
| `statusline.py` | Python 3 | none       | macOS, Linux, Windows (if Python installed) |
| `statusline.js` | Node.js  | none       | macOS, Linux, Windows (if Node installed)   |
| `statusline.sh` | bash     | `jq`, `awk`  | macOS, Linux, Windows (Git Bash)      |

**Recommendation:**
- **Python 3** if you have it — ships with macOS and most Linux distros. This is
  the version that is verified byte-for-byte against the bash reference (13
  test cases). On Windows, install Python from python.org or the Store.
- **Node.js** if that's your daily runtime instead. (Note: the modern native
  Claude Code installer is a standalone binary and does **not** bundle Node, so
  don't assume it's present just because Claude Code is.)
- **bash** on macOS/Linux only if you're happy to `brew install jq` /
  `apt install jq`. On macOS `jq` is **not** preinstalled.

### Install

**Easiest — let Claude Code do it:**

```bash
git clone https://github.com/joeytroy/claude-scripts
cd claude-scripts
claude
```

then just say **"install the status line"**. The repo's `CLAUDE.md` tells
Claude how: it detects which runtime you have, points your
`~/.claude/settings.json` at the script in the clone (so `git pull` picks up
updates), and verifies the output. No manual copying or JSON editing.

**Manual:**

Copy your chosen script into `~/.claude/` (or anywhere), then point Claude Code
at it in `~/.claude/settings.json`:

**Python (recommended):**
```json
{
  "statusLine": {
    "type": "command",
    "command": "python3 ~/.claude/statusline.py"
  }
}
```
On Windows, use `"command": "python %USERPROFILE%\\.claude\\statusline.py"`.

**Node:**
```json
{ "statusLine": { "type": "command", "command": "node ~/.claude/statusline.js" } }
```

**bash (macOS / Linux / Git Bash):**
```json
{ "statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh" } }
```

Restart Claude Code afterward — the status line is loaded at startup.

### Notes on fields

- **cwd, model, cost, duration** — standard status-line payload fields; always populate.
- **`context_window` / `rate_limits`** — only render if your Claude Code version
  includes them in the payload; otherwise those segments are silently omitted.
- **effort** — read from the payload field `effort.level`
  (`low`/`medium`/`high`/`xhigh`/`max`; ultracode reports as `xhigh`). This is
  the live session value, so mid-session `/effort` changes show up. On older
  Claude Code versions without the field, falls back to the
  `CLAUDE_CODE_EFFORT_LEVEL` env var, then the `effortLevel` key in
  `.claude/settings.json` (project, then user). Omitted when the model has no
  effort parameter and no fallback is set.
- Fractional percentages round half **up** in all three implementations
  (62.5 → 63).

### Test locally

```bash
echo '{
  "workspace": {"current_dir": "/home/you/project"},
  "model": {"display_name": "Opus 4.8"},
  "effort": {"level": "high"},
  "cost": {"total_cost_usd": 0.1234, "total_duration_ms": 3725000},
  "context_window": {"used_percentage": 62.5},
  "rate_limits": {"five_hour": {"used_percentage": 20}, "seven_day": {"used_percentage": 5}}
}' | python3 statusline.py
```

Swap `python3 statusline.py` for `node statusline.js` or `bash statusline.sh`.
