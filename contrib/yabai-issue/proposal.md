## Summary

Several community projects now provide a graphical front end for yabai. The most
established is [YabaiIndicator](https://github.com/xiamaz/YabaiIndicator), a menu bar
applet with more than 300 stars, together with a handful of Übersicht widgets, help
overlays and dock companions.

None of them are mentioned in this repository or in the wiki, which makes them hard to
find for people who land on the wiki without knowing the message passing interface.

Pull requests are disabled on this repository, so this issue is the place to propose the
addition.

## Proposed wiki page

A new **Graphical interfaces** page in the wiki, listing the projects that already
exist:

| Project | What it does |
|---|---|
| [YabaiBar](https://github.com/remixeco/YabaiBar) | Menu bar app that starts, stops and updates yabai and skhd, and edits both configuration files |
| [YabaiIndicator](https://github.com/xiamaz/YabaiIndicator) | Menu bar applet that shows the current space and switches between spaces |
| [yabai-help-overlay](https://github.com/arunvelsriram/yabai-help-overlay) | Help overlay listing the available keybindings |
| [yabai-uberbar](https://github.com/AdamWagner/yabai-uberbar) | Übersicht bar with a graphical overview of the windows on each space |
| [yabai-status-bar](https://github.com/qhuyduong/yabai-status-bar) | Übersicht widget with a status bar for yabai |
| [yabai-dockstack](https://github.com/z20240/yabai-dockstack) | Stack indicators and cross-space window decorations |

The page would state explicitly that these are community projects and not part of
yabai, and that nothing on it is required to use yabai.

## Ready to apply

The wiki is a separate git repository, so the page can be added with a pull request
there:

<https://github.com/asmvik/yabai.wiki>

The complete page content, together with the two edits it needs (`_Sidebar.md` and
`Home.md`), is ready in the YabaiBar repository:

<https://github.com/remixeco/YabaiBar/tree/main/contrib/yabai-wiki>

## Optional: one line in the README

The *Installation and Configuration* section already mentions skhd and "other
third-party software". A single line pointing to the new page would be enough:

```diff
 - Keyboard shortcuts can be defined with skhd or any other suitable software you may prefer.
+- Graphical front ends for yabai are available as community projects; see the graphical interfaces page of the wiki.
```

That change is ready on a branch, if it is welcome:

<https://github.com/remixeco/yabai/compare/master...feature/graphical-interfaces-link>

## Note

This is a proposal from a user of the project, not a requirement. If the wiki stays the
way it is, that is perfectly fine — YabaiBar has its own documentation, its own
Homebrew cask and its own releases, and does not need anything from this repository.
