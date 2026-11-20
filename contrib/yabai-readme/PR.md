# Pull request — asmvik/yabai README

Adds one bullet to the **Installation and Configuration** section pointing to
the wiki's new *graphical interfaces* page.

## The change

```diff
 - Keyboard shortcuts can be defined with skhd or any other suitable software you may prefer.
+- Graphical front ends for yabai are available as community projects; see the graphical interfaces page of the wiki.
```

Two lines in total: the bullet, and the matching link definition.

## Why

The README already mentions that keyboard shortcuts can be set with
"skhd and other third-party software", and the About section says yabai
integrates with "other third-party software". Several community projects
already provide a graphical front end — `YabaiIndicator` has more than 300
stars — but nothing in the repository points to them, and the wiki does not
mention any of them either.

This pull request only adds a pointer to a wiki page. The page itself lists
the existing tools next to the new one, and every project is described in one
factual line.

Nothing here is required to use yabai, and the bullet is written so that
dropping the wiki page would not break the link.

## Order of operations

The README links to a wiki page that does not exist yet, so the wiki pull
request should be submitted **first**. If the maintainer would rather not have
the README point at the wiki, the alternative is to submit the wiki page on
its own — it stands on its own without the README change.

## How to submit

```sh
git clone https://github.com/remixeco/yabai.git
cd yabai
git remote add upstream https://github.com/asmvik/yabai.git
git checkout -b add-graphical-interfaces-link

# apply the patch
git apply ../contrib/yabai-readme/README.patch

git commit -am "Link to the graphical interfaces page of the wiki"
git push -u origin add-graphical-interfaces-link
```

Then open <https://github.com/asmvik/yabai/pulls> and create the pull request.
