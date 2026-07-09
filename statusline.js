#!/usr/bin/env node
// Claude Code status line — cross-platform (macOS, Windows, Linux).
// Reads session JSON from stdin, prints one formatted line to stdout.
// Zero external dependencies: uses only Node's stdlib, which Claude Code
// guarantees is present on every platform. No jq / awk / bash required.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

// --- ANSI colors ---
const C = {
  reset: '\x1b[0m',
  dim: '\x1b[2m',
  cyan: '\x1b[36m',
  yellow: '\x1b[33m',
  green: '\x1b[32m',
  magenta: '\x1b[35m',
  blue: '\x1b[34m',
  red: '\x1b[31m',
};

// Read all of stdin synchronously (fd 0).
function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

// Safe nested lookup: get(obj, 'a.b.c').
function get(obj, dotted) {
  return dotted.split('.').reduce(
    (o, k) => (o != null && typeof o === 'object' ? o[k] : undefined),
    obj
  );
}

// First defined/non-null value among several dotted paths.
function pick(obj, ...paths) {
  for (const p of paths) {
    const v = get(obj, p);
    if (v !== undefined && v !== null && v !== '') return v;
  }
  return undefined;
}

// Coerce to an integer, or null if not numeric. Math.round rounds half up,
// which is the convention all three implementations follow (inputs are
// non-negative percentages/durations).
function toInt(v) {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n) : null;
}

function main() {
  const raw = readStdin();
  let data = {};
  try {
    data = JSON.parse(raw) || {};
  } catch {
    data = {};
  }

  const cwd = pick(data, 'workspace.current_dir', 'cwd');
  const model = pick(data, 'model.display_name');
  const totalCost = pick(data, 'cost.total_cost_usd');
  const durationMs = pick(data, 'cost.total_duration_ms');
  const ctxUsed = pick(data, 'context_window.used_percentage');
  const fiveHr = pick(data, 'rate_limits.five_hour.used_percentage');
  const sevenDay = pick(data, 'rate_limits.seven_day.used_percentage');

  // Effort: the payload field effort.level is the live session value
  // (tracks mid-session /effort changes; absent when the model has no
  // effort parameter). Fall back to the env var, then the effortLevel
  // settings key, for older Claude Code versions without the field.
  let effort =
    pick(data, 'effort.level') || process.env.CLAUDE_CODE_EFFORT_LEVEL;
  if (!effort) {
    const settingsPaths = [
      path.join(process.cwd(), '.claude', 'settings.json'),
      path.join(os.homedir(), '.claude', 'settings.json'),
    ];
    for (const sp of settingsPaths) {
      try {
        const s = JSON.parse(fs.readFileSync(sp, 'utf8'));
        effort = s.effortLevel || undefined;
        if (effort) break;
      } catch {
        /* missing or unparseable — ignore */
      }
    }
  }

  const parts = [];

  // Working directory (shorten home dir -> ~).
  if (cwd) {
    const home = os.homedir();
    let shown = String(cwd);
    if (home && shown.startsWith(home)) shown = '~' + shown.slice(home.length);
    parts.push(`${C.cyan}${shown}${C.reset}`);
  }

  if (model) parts.push(`${C.blue}${model}${C.reset}`);
  if (effort) parts.push(`effort:${C.yellow}${effort}${C.reset}`);

  // Context used %  (green <50, yellow <80, red >=80)
  const ctxInt = toInt(ctxUsed);
  if (ctxInt !== null) {
    const c = ctxInt >= 80 ? C.red : ctxInt >= 50 ? C.yellow : C.green;
    parts.push(`ctx:${c}${ctxInt}%${C.reset}`);
  }

  // Rate limits
  const quota = [];
  const p5 = toInt(fiveHr);
  if (p5 !== null) quota.push(`5h:${C.magenta}${p5}%${C.reset}`);
  const p7 = toInt(sevenDay);
  if (p7 !== null) quota.push(`7d:${C.magenta}${p7}%${C.reset}`);
  if (quota.length) parts.push(`quota:${quota.join(' ')}`);

  // Cost
  if (totalCost !== undefined && totalCost !== null) {
    const n = Number(totalCost);
    if (Number.isFinite(n)) {
      parts.push(`cost:${C.green}$${n.toFixed(4)}${C.reset}`);
    }
  }

  // Duration (from total_duration_ms)
  const dsec = toInt(durationMs);
  if (dsec !== null) {
    const s = Math.floor(dsec / 1000);
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const sec = s % 60;
    const pad = (x) => String(x).padStart(2, '0');
    const durationStr =
      h > 0 ? `${h}h${pad(m)}m` : `${m}m${pad(sec)}s`;
    parts.push(`${C.dim}${durationStr}${C.reset}`);
  }

  process.stdout.write(parts.join(' | '));
}

main();
