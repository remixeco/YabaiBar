# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-20

### Added

- Menu bar app that starts, stops and restarts yabai without a terminal.
- Dashboard window with the yabai state, the launchd service and a live log.
- Full editor for the skhd shortcuts: structured view with a key recorder,
  raw text view, mode filter, add and remove.
- Live editor for the yabai layout, placement, gap and padding, with the
  option to write the values back to `yabairc`.
- Update flow running `brew update` and `brew upgrade yabai`, followed by a
  service restart so the new binary is loaded.
- Diagnostics: paths, service state, launch at login and the yabai logs.
- `YabaiBar --screenshots <dir>` renders the interface to PNG files, so the
  documentation images always match the code.

[1.0.0]: https://github.com/remixeco/YabaiBar/releases/tag/v1.0.0
