-----

<!-- Do not tick a checkbox if you haven't performed its action. -->

After making any changes to a cask, existing or new, verify:

- [x] The submission is for [a stable version](https://docs.brew.sh/Acceptable-Casks#stable-versions) or [documented exception](https://docs.brew.sh/Acceptable-Casks#but-there-is-no-stable-version).
- [x] `brew audit --cask --online <cask>` is error-free.
- [x] `brew style --fix <cask>` reports no offenses.

Additionally, if adding a new cask:

- [x] Named the cask according to the [token reference](https://docs.brew.sh/Cask-Cookbook#token-reference).
- [x] Checked the cask was not [already refused](https://github.com/search?q=repo%3AHomebrew%2Fhomebrew-cask+is%3Aclosed+is%3Aunmerged+&type=pullrequests) (add your cask's name to the end of the search field).
- [x] `brew audit --cask --new <cask>` worked successfully.
- [x] `HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask <cask>` worked successfully.
- [x] `brew uninstall --cask <cask>` worked successfully.

-----

- [x] I did not use AI/LLM to create this PR, or I disclosed the tool/model below and reviewed its output, including [`zap` stanza](https://docs.brew.sh/Cask-Cookbook#stanza-zap) paths; every commit has a human author or co-author and I will answer maintainer questions and review comments myself without AI/LLM.

<!-- If AI was used, explain below how it was used and how you verified the changes. -->

-----

## Disclosure

This cask and the pull request text were drafted with an AI coding assistant
(OpenCode, running on Claude) and reviewed line by line by the maintainer.

What the assistant produced, and how it was verified:

- the cask file itself, checked against `brew style --fix` (no offenses) and
  `brew audit --cask --online` (no offenses);
- the install, uninstall and upgrade paths, checked by running them on macOS;
- the `zap` stanza, with every path verified against the bundle identifier
  `com.yabaibar.YabaiBar` — no path is guessed, each one was created by running
  the app with the relevant feature enabled.

The maintainer answers maintainer questions and reviews the comments on this
pull request directly.

## About the application

YabaiBar is a menu bar companion for the [yabai](https://github.com/asmvik/yabai)
tiling window manager and for [skhd](https://github.com/asmvik/skhd).

It is an accessory app: it lives in the menu bar and has no Dock icon. The menu
bar glyph is a binary space partitioning layout that changes colour with the state
of yabai — green when it runs, grey when it is stopped, blue while something is
happening.

From the menu bar panel you can start, stop and restart yabai, reload the
configuration, open the logs, check for updates and relaunch the app.

The dashboard window adds:

- a complete editor for the `skhdrc` shortcuts, with a key recorder and a raw
  text view
- live editing of the layout, placement, gap and padding, with the option to
  write the values back to `yabairc`
- an update flow running `brew update` and `brew upgrade yabai`, followed by a
  service restart so the new binary is the one running
- the yabai and skhd logs, and the state of the launchd service

yabai and skhd themselves are not bundled and are installed the usual way, with
`brew install asmvik/formulae/yabai`.

Repository: <https://github.com/remixeco/YabaiBar>
