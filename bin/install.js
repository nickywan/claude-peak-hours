#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");

const CLAUDE_DIR = path.join(os.homedir(), ".claude");
const SETTINGS_FILE = path.join(CLAUDE_DIR, "settings.json");
const STATUSLINE_DEST = path.join(CLAUDE_DIR, "statusline.sh");
const STATUSLINE_SRC = path.resolve(__dirname, "statusline.sh");

const blue = "\x1b[38;2;0;153;255m";
const green = "\x1b[38;2;0;175;80m";
const red = "\x1b[38;2;255;85;85m";
const yellow = "\x1b[38;2;230;200;0m";
const dim = "\x1b[2m";
const reset = "\x1b[0m";

function log(msg) { console.log(`  ${msg}`); }
function success(msg) { console.log(`  ${green}✓${reset} ${msg}`); }
function warn(msg) { console.log(`  ${yellow}!${reset} ${msg}`); }
function fail(msg) { console.error(`  ${red}✗${reset} ${msg}`); }

function checkDeps() {
  const { execSync } = require("child_process");
  const missing = [];
  try { execSync("which jq", { stdio: "ignore" }); } catch { missing.push("jq"); }
  try { execSync("which curl", { stdio: "ignore" }); } catch { missing.push("curl"); }
  return missing;
}

function uninstall() {
  console.log();
  console.log(`  ${blue}claude-peak-hours Uninstaller${reset}`);
  console.log(`  ${dim}─────────────────────────────${reset}`);
  console.log();

  const backup = STATUSLINE_DEST + ".bak";
  if (fs.existsSync(backup)) {
    fs.copyFileSync(backup, STATUSLINE_DEST);
    fs.unlinkSync(backup);
    success(`Restored previous statusline from ${dim}statusline.sh.bak${reset}`);
  } else if (fs.existsSync(STATUSLINE_DEST)) {
    fs.unlinkSync(STATUSLINE_DEST);
    success(`Removed ${dim}statusline.sh${reset}`);
  } else {
    warn("No statusline found — nothing to remove");
  }

  if (fs.existsSync(SETTINGS_FILE)) {
    try {
      const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf-8"));
      if (settings.statusLine) {
        delete settings.statusLine;
        fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + "\n");
        success(`Removed statusLine from ${dim}settings.json${reset}`);
      } else {
        success("Settings already clean");
      }
    } catch {
      fail(`Could not parse ${SETTINGS_FILE} — fix it manually`);
      process.exit(1);
    }
  }

  console.log();
  log(`${green}Done!${reset} Restart Claude Code to apply changes.`);
  console.log();
}

function run() {
  const args = process.argv.slice(2);

  if (args.includes("--uninstall")) {
    uninstall();
    return;
  }

  // Parse flags
  const mode = args.includes("--full") ? "full" : "minimal";
  const timeFmt = args.includes("--24h") ? "--24h" : args.includes("--12h") ? "--12h" : "";
  let lang = "";
  const langIdx = args.indexOf("--lang");
  if (langIdx !== -1 && args[langIdx + 1]) {
    lang = `--lang ${args[langIdx + 1]}`;
  }

  console.log();
  console.log(`  ${blue}claude-peak-hours Installer${reset}`);
  console.log(`  ${dim}───────────────────────────${reset}`);
  console.log();

  const missing = checkDeps();
  if (missing.length > 0) {
    fail(`Missing required dependencies: ${missing.join(", ")}`);
    if (missing.includes("jq")) {
      const hint = process.platform === "darwin"
        ? "brew install jq"
        : "sudo apt install jq  # or: sudo pacman -S jq";
      log(`  ${dim}${hint}${reset}`);
    }
    process.exit(1);
  }
  success("Dependencies found (jq, curl)");

  if (!fs.existsSync(CLAUDE_DIR)) {
    fs.mkdirSync(CLAUDE_DIR, { recursive: true });
    success(`Created ${CLAUDE_DIR}`);
  }

  const backup = STATUSLINE_DEST + ".bak";
  if (fs.existsSync(STATUSLINE_DEST)) {
    fs.copyFileSync(STATUSLINE_DEST, backup);
    warn(`Backed up existing statusline to ${dim}statusline.sh.bak${reset}`);
  }

  fs.copyFileSync(STATUSLINE_SRC, STATUSLINE_DEST);
  fs.chmodSync(STATUSLINE_DEST, 0o755);
  success(`Installed statusline to ${dim}${STATUSLINE_DEST}${reset}`);

  let settings = {};
  if (fs.existsSync(SETTINGS_FILE)) {
    try {
      settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf-8"));
    } catch {
      fail(`Could not parse ${SETTINGS_FILE} — fix it manually`);
      process.exit(1);
    }
  }

  const flags = [
    mode === "full" ? "--full" : "",
    timeFmt,
    lang,
  ].filter(Boolean).join(" ");

  const command = flags
    ? `bash "$HOME/.claude/statusline.sh" ${flags}`
    : `bash "$HOME/.claude/statusline.sh"`;

  settings.statusLine = { type: "command", command };
  fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + "\n");
  success(`Updated ${dim}settings.json${reset} with statusLine config`);

  console.log();
  log(`  Mode:      ${blue}${mode}${reset}`);
  log(`  Time:      ${blue}${timeFmt || "auto-detect"}${reset}`);
  log(`  Language:   ${blue}${lang || "auto-detect"}${reset}`);
  console.log();
  log(`  ${dim}Reconfigure anytime:${reset}`);
  log(`  ${dim}  npx cc-peak-hours                         ${reset}${dim}← minimal${reset}`);
  log(`  ${dim}  npx cc-peak-hours --full --24h --lang fr  ${reset}${dim}← full, 24h, French${reset}`);
  log(`  ${dim}  npx cc-peak-hours --uninstall             ${reset}${dim}← restore previous${reset}`);
  console.log();
  log(`${green}Done!${reset} Restart Claude Code to see your new status line.`);
  console.log();
}

run();
