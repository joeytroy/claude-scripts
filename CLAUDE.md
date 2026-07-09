# claude-scripts

Cross-platform Claude Code status line: three implementations (`statusline.py`,
`statusline.js`, `statusline.sh`) that must render **byte-identical** output.
`test.sh` verifies this — run `bash test.sh` after touching any of them, and
apply every behavior change to all three implementations, not just one.

## Installing the status line for the user

When the user asks to "install", "set up", or "enable" the status line, do it
for them:

1. **Pick an implementation** by checking what's installed, in this order:
   - `python3` (or `python` on Windows) → `statusline.py`
   - `node` → `statusline.js`
   - `bash` + `jq` → `statusline.sh`
   If none are available, say so and suggest installing Python 3.

2. **Point settings at the script in this clone** (preferred — `git pull` then
   picks up updates). Merge into `~/.claude/settings.json`, preserving all
   existing keys; create the file with `{}` semantics if it doesn't exist:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "python3 /absolute/path/to/this/clone/statusline.py"
     }
   }
   ```

   Use the real absolute path and the matching runtime (`node …/statusline.js`
   or `bash …/statusline.sh`). On Windows use `python` and a Windows path.
   If the user prefers a copy independent of the clone, copy the script to
   `~/.claude/` and reference it there instead.

   If `statusLine` already exists in settings, show the user the current value
   and confirm before replacing it.

3. **Verify** by piping a sample payload:

   ```bash
   echo '{"model":{"display_name":"Test"},"effort":{"level":"high"},"context_window":{"used_percentage":42}}' \
     | python3 statusline.py
   ```

   Expect something like `Test | effort:high | ctx:42%` (with ANSI colors).

4. Tell the user to **restart Claude Code** — the status line command is loaded
   at startup.

## Field conventions

- Effort comes from payload `effort.level` first, then the
  `CLAUDE_CODE_EFFORT_LEVEL` env var, then `effortLevel` in settings
  (project, then user). Missing fields render as omitted segments, never
  errors.
- Fractional percentages round half up (62.5 → 63) in all implementations.
- Scripts must never crash on empty/garbage stdin — they print whatever
  segments they can.
