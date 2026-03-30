# claude-peak-hours

A Claude Code statusline that shows whether you're in **peak** or **off-peak** hours, with a countdown to the next transition.

During peak hours (12:00–18:00 UTC / 8AM–2PM ET on weekdays), Anthropic applies stricter session limits. This statusline shows you exactly when you're in peak, when it changes, and helps you plan your usage.

## Install

```bash
npx claude-peak-hours
```

Restart Claude Code after installing.

### Options

```bash
npx claude-peak-hours                      # minimal (default)
npx claude-peak-hours --full               # dashboard with timeline + rate limits
npx claude-peak-hours --24h               # force 24h time format
npx claude-peak-hours --12h               # force 12h time format
npx claude-peak-hours --lang fr            # French labels
npx claude-peak-hours --full --24h --lang fr  # combined
npx claude-peak-hours --uninstall          # restore previous statusline
```

## Modes

### Minimal (default)

One line. Everything you need at a glance.

**During off-peak:**
```
Opus 4.6 │ 39% │ ⚡ Off-peak ~ Peak 14:00 (5h12m)
```

**During peak hours:**
```
Opus 4.6 │ 39% │ Peak ~ Off-peak 20:00 (2h15m)
```

**Weekend:**
```
Opus 4.6 │ 39% │ ⚡ Off-peak ~ Peak Mon. 14:00 (1d8h)
```

### Full (`--full`)

Dashboard with visual timeline and real-time rate limits.

**During off-peak:**
```
Opus 4.6 │ 39% │ ⚡ Off-peak ~ Peak 14:00 (5h12m)

today  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━━━━━  ━ off-peak ━ peak 14:00-20:00  ● now
current ●●●●○○○○○○  42% ⟳ 22:00 │ weekly  ●●●○○○○○○○  31% ⟳ mar 20
```

**Weekend (all day off-peak):**
```
Opus 4.6 │ 12% │ ⚡ Off-peak ~ Peak Mon. 14:00 (1d14h)

today  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━━━━━  ━ off-peak all day  ● now
current ●○○○○○○○○○   5% ⟳ 20:00 │ weekly  ●●○○○○○○○○  15% ⟳ mar 22
```

The timeline bar shows your full day in local time -- green (`━`) for off-peak hours, yellow (`━`) for peak hours, and a white dot (`●`) for where you are now.

## Localization

Supports English (default) and French. Auto-detected from your locale, or forced with `--lang`.

**French example:**
```
Opus 4.6 │ 39% │ ⚡ Hors pointe ~ Pointe 14:00 (5h12m)
```

## Time format

Auto-detected from locale (French -> 24h, English -> 12h), or forced with `--24h` / `--12h`.

## Remote config

Peak hours are loaded from a [remote config file](peak-hours.json) on this repo, cached locally for 1 hour. If Anthropic changes peak hours, updating this file updates all users automatically -- no plugin update needed.

Falls back to hardcoded defaults (Mon-Fri 12:00-18:00 UTC) if the fetch fails.

## How it works

- Loads peak hours config from GitHub (cached 1h, hardcoded fallback)
- All peak calculations done in **UTC** -- no DST ambiguity
- Converts to your local timezone for display
- Fetches real rate limits via Claude's OAuth API (cached 60s) in full mode
- Supports multiple peak windows and midnight-crossing windows

## Requirements

- **macOS or Linux**
- **jq** -- `brew install jq` or `sudo apt install jq`
- **curl** -- pre-installed on most systems

## License

MIT
