# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-31

### Added

- Minimal mode: single-line statusline with model, context %, peak status, and countdown
- Full mode (`--full`): dashboard with visual timeline bar and real-time rate limits via OAuth API
- Remote config (`peak-hours.json`): peak hours loaded from GitHub, cached 1h, hardcoded fallback
- Multi-window support: multiple peak windows per day, midnight-crossing windows
- Localization: English (default) and French (`--lang fr`), auto-detected from locale
- Time format: 12h/24h (`--12h`/`--24h`), auto-detected from locale
- Node installer (`npx claude-peak-hours`): backup, install, uninstall, flag forwarding
- macOS and Linux support (GNU coreutils + BSD date)
