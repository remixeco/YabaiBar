# Pull request — yabai wiki

Adds a **Graphical interfaces** page listing the community projects that wrap
yabai in a GUI, and links it from the sidebar and the quickstart guide.

## Why

yabai is entirely command line driven, which is a barrier for people who
land on the wiki without knowing the message passing interface. Several
community projects already fill that gap — `YabaiIndicator` is a menu bar
applet with more than 300 stars — but the wiki does not mention any of them.

The page is deliberately a catalogue: it lists the existing tools next to the
new one, and each project gets a short factual description. Nothing in this
page is required to use yabai.

## Files

| File | Change |
|---|---|
| `Graphical-interfaces.md` | New page |
| `_Sidebar.md` | New entry under **General** |
| `Home.md` | Link in the quickstart guide, step 4 |

## How to submit

The wiki is a separate git repository, so the change goes through a pull
request like any other:

```sh
# 1. Fork the wiki
git clone https://github.com/remixeco/yabai.wiki.git
cd yabai.wiki
git remote add upstream https://github.com/asmvik/yabai.wiki.git

# 2. Add the files from this directory
cp ../contrib/yabai-wiki/Graphical-interfaces.md .
cp ../contrib/yabai-wiki/_Sidebar.md .
cp ../contrib/yabai-wiki/Home.md .

# 3. Commit on a branch
git checkout -b add-graphical-interfaces-page
git add Graphical-interfaces.md _Sidebar.md Home.md
git commit -m "Add graphical interfaces page"

# 4. Push and open the pull request
git push -u origin add-graphical-interfaces-page
```

Then open <https://github.com/asmvik/yabai.wiki/pulls> and create the pull
request from `add-graphical-interfaces-page`.

The wiki can also be edited directly from the browser: open any page, click
**Edit**, then the **Publish** button — GitHub offers to create a pull
request for the wiki fork.

## Note for the reviewer

If listing a specific project is considered too promotional, the page still
works as a catalogue of the other tools — the **YabaiBar** section and the
screenshot links can be dropped without touching the rest.
