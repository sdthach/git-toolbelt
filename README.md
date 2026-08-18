<div align="center">
  <img src="./img/git-toolbelt.png" width="376" height="409" alt="git-toolbelt logo" /><br>
</div>

# git-toolbelt

Helper tools to make everyday life with Git much easier — a set of small, focused `git-*` scripts that each install as their own `git <verb>` subcommand, plus a set of short `g`+verb shortcuts for the ones you reach for the most. This is a personal fork of [`nvie/git-toolbelt`](https://github.com/nvie/git-toolbelt); see [`docs/maintaining-the-fork.md`](docs/maintaining-the-fork.md) for how it relates to upstream.

## Prerequisites & install

Requires `git` plus either [mise](https://mise.jdx.dev) or [Homebrew](https://brew.sh); a couple of commands have optional dependencies (`realpath` from GNU coreutils, `fzf`). The commands are pure POSIX `sh`, so one platform-independent build covers macOS, Linux, and WSL alike, and both package managers install that same build:

```console
$ mise use -g github:sdthach/git-toolbelt   # or:
$ brew install sdthach/tap/git-toolbelt
```

Either puts all 77 commands on `PATH` — `git-*` scripts as `git <verb>` subcommands, `g`+verb shortcuts as standalone commands. Full details, including version pinning, `--HEAD` builds, and a note for developing on this repo directly: **[docs/install.md](docs/install.md)**.

## Layout

```
git-toolbelt/
├── git-*          # 63 standalone git subcommands (see docs/commands.md)
├── portmanteaus/  # 14 g+verb shortcuts: getch, gadd, gommit, gush, ... (see docs/portmanteaus.md)
├── docs/          # install / commands / portmanteaus / maintaining-the-fork
├── scripts/       # build-dist.sh (release tarball) + smoke-test.sh
├── packaging/     # Homebrew formula, source of truth for the tap copy
├── mise.toml      # dev environment + lint/build/smoke tasks
└── CHANGELOG.md / PUBLISHING.md / LICENSE
```

The repo layout is not the shipped layout: `git-*` stays at the root so merges from upstream stay clean, and [`scripts/build-dist.sh`](scripts/build-dist.sh) flattens both directories into the `bin/` that the release tarball carries. See [`docs/maintaining-the-fork.md`](docs/maintaining-the-fork.md).

## Commands

Full write-ups live in [`docs/commands.md`](docs/commands.md) (the `git-*` scripts) and [`docs/portmanteaus.md`](docs/portmanteaus.md) (the `g`+verb shortcuts). Below is a quick index — expand a category to jump straight to a command's docs.

Not sure whose git-toolbelt is on your `PATH`? [`git-toolbelt`](docs/commands.md#git-toolbelt) is the one command upstream doesn't ship — `git toolbelt` prints the installed version and identifies this fork.

<details>
<summary><strong>Everyday</strong></summary>

- ⭐️ [`git-cleanup`](docs/commands.md#git-cleanup) — delete branches already merged into main, locally and on origin
- [`git-current-branch`](docs/commands.md#git-current-branch) — print the current branch name
- [`git-main-branch`](docs/commands.md#git-main-branch) — print the repo's default main branch (`main`/`master`)
- ⭐️ [`git-fixup`](docs/commands.md#git-fixup) — amend staged changes into the last commit
- [`git-autofixup`](docs/commands.md#git-autofixup) — auto-target `git commit --fixup` at the commit that last touched your staged files
- ⭐️ [`git-fixup-with`](docs/commands.md#git-fixup-with) — pick a commit to fix up via `fzf`
- ⭐️ [`git-active-branches`](docs/commands.md#git-local-branches--git-remote-branches--git-active-branches) — branches with recent activity
- ⭐️ [`git-diff-since`](docs/commands.md#git-diff-since) — diff current branch against main
- [`git-local-branches`](docs/commands.md#git-local-branches--git-remote-branches--git-active-branches) — machine-processable local branch list
- [`git-local-commits`](docs/commands.md#git-local-commits--git-has-local-commits) — commits not yet pushed to origin
- [`git-merged` / `git-unmerged` / `git-merge-status`](docs/commands.md#git-merged--git-unmerged--git-merge-status) — merge status of local branches
- [`git-branches-containing`](docs/commands.md#git-branches-containing) — branches containing a given commit
- [`git-recent-branches`](docs/commands.md#git-recent-branches) — local branches ordered by recency
- [`git-remote-branches`](docs/commands.md#git-local-branches--git-remote-branches--git-active-branches) — machine-processable remote branch list
- [`git-remote-tracking-branch`](docs/commands.md#git-remote-tracking-branch) — print a branch's remote tracking branch
- [`git-root`](docs/commands.md#git-root) — print the working tree root
- [`git-initial-commit`](docs/commands.md#git-initial-commit) — print the repo's first commit
- ⭐️ [`git-sha`](docs/commands.md#git-sha) — print an object's SHA
- [`git-stage-all`](docs/commands.md#git-stage-all) — mirror the working tree into the index
- [`git-unstage-all`](docs/commands.md#git-unstage-all) — unstage everything
- [`git-update-all`](docs/commands.md#git-update-all) — fast-forward all local branches from their remotes
- [`git-workon`](docs/commands.md#git-workon) — switch to (or create-and-track) a branch by name
- ⭐️ [`git-modified`](docs/commands.md#git-modified) — list locally modified files
- ⭐️ [`git-modified-since`](docs/commands.md#git-modified-since) — list files modified since branching off main
- [`git-last-commit-to-file`](docs/commands.md#git-last-commit-to-file) — SHA of the commit that last touched a file
- ⭐️ [`git-separator`](docs/commands.md#git-separator) — add a visual `---` separator commit
- ⭐️ [`git-spinoff`](docs/commands.md#git-spinoff) — spin the current branch's unpushed work onto a new branch
- ⭐️ [`git-wip`](docs/commands.md#git-wip) — quick "WIP" savepoint commit(s)

</details>

<details>
<summary><strong>Statistics</strong></summary>

- [`git-committer-info`](docs/commands.md#git-committer-info) — contribution stats for a committer

</details>

<details>
<summary><strong>Novice</strong></summary>

- [`git-drop-local-changes`](docs/commands.md#git-drop-local-changes) — hard-reset back to the last commit, no exceptions
- [`git-stash-everything`](docs/commands.md#git-stash-everything) — stash index, working tree, and untracked files together
- ⭐️ [`git-push-current`](docs/commands.md#git-push-current) — push the current branch and set up tracking
- [`git-undo-commit`](docs/commands.md#git-undo-commit) — undo the last commit, keeping its changes staged
- [`git-undo-merge`](docs/commands.md#git-undo-merge) — undo the last merge
- [`git-trash`](docs/commands.md#git-trash) — commit-then-hard-reset everything away (recoverable via reflog)

</details>

<details>
<summary><strong>Scripting</strong></summary>

- [`git-is-repo`](docs/commands.md#git-is-repo) — is the cwd inside a Git repo?
- [`git-is-headless`](docs/commands.md#git-is-headless) — is `HEAD` detached?
- [`git-has-local-changes` / `git-is-clean` / `git-is-dirty`](docs/commands.md#git-has-local-changes--git-is-clean--git-is-dirty) — working tree cleanliness as an exit code
- [`git-has-local-commits`](docs/commands.md#git-local-commits--git-has-local-commits) — are there unpushed commits?
- [`git-contains` / `git-is-ancestor`](docs/commands.md#git-contains--git-is-ancestor) — is X merged into / an ancestor of Y?
- [`git-local-branch-exists` / `git-remote-branch-exists` / `git-tag-exists`](docs/commands.md#git-local-branch-exists--git-remote-branch-exists--git-tag-exists) — does a local branch / remote branch / tag exist?
- [`git-relative-path`](docs/commands.md#git-relative-path) — resolve a repo-root-relative path via GNU `realpath`

</details>

<details>
<summary><strong>Advanced</strong></summary>

- [`git-skip` / `git-unskip` / `git-show-skipped`](docs/commands.md#git-skip--git-unskip--git-show-skipped) — toggle "skip worktree" on files
- [`git-commit-to`](docs/commands.md#git-commit-to) — commit staged changes onto a different branch
- [`git-cherry-pick-to`](docs/commands.md#git-cherry-pick-to) — cherry-pick a commit onto another branch without switching
- ⭐️ [`git-delouse`](docs/commands.md#git-delouse) — empty the last commit, keep its message, restore its changes
- ⭐️ [`git-shatter-by-file`](docs/commands.md#git-shatter-by-file) — split the last commit into one commit per file
- ⭐️ [`git-cleave`](docs/commands.md#git-cleave) — split the last commit by file path patterns
- [`git-edit-author-dates`](docs/commands.md#git-edit-author-dates) — interactively rewrite author dates via rebase
- [`git-amend-date`](docs/commands.md#git-amend-date) — set `HEAD`'s author/committer date (plumbing for the above)
- [`git-sync-commit-date`](docs/commands.md#git-sync-commit-date) — reset `HEAD`'s committer date to match its author date
- [`git-conflicts`](docs/commands.md#git-conflicts) — report which local branches would merge uncleanly
- [`git-merges-cleanly`](docs/commands.md#git-merges-cleanly) — exit-code check of whether a branch merges cleanly
- [`git-force-checkout`](docs/commands.md#git-force-checkout-planned) — planned, not yet implemented

</details>

<details>
<summary><strong>Portmanteau shortcuts</strong></summary>

Short `g`+verb executables — no `git ` prefix needed. Full reference, including which are thin passthroughs vs. smart wrappers: [`docs/portmanteaus.md`](docs/portmanteaus.md).

- [`getch`](docs/portmanteaus.md#reference) — `git fetch`
- [`gull`](docs/portmanteaus.md#reference) — `git pull`
- [`gulp`](docs/portmanteaus.md#reference) — fetch, then pull
- [`gush`](docs/portmanteaus.md#reference) — `git push-current`
- [`gadd`](docs/portmanteaus.md#reference) — `git add`
- [`gommit`](docs/portmanteaus.md#reference) — `git commit`
- [`gamend`](docs/portmanteaus.md#reference) — `git commit --amend`
- [`gatus`](docs/portmanteaus.md#reference) — `git status`
- [`giff`](docs/portmanteaus.md#reference) — `git diff`
- [`glog`](docs/portmanteaus.md#reference) — `git log`
- [`granch`](docs/portmanteaus.md#reference) — `git branch`
- [`gtash`](docs/portmanteaus.md#reference) — `git stash`
- [`gout`](docs/portmanteaus.md#reference) — `git workon`
- [`gome`](docs/portmanteaus.md#reference) — checkout main branch

</details>

## Background

[`docs/distribution-rework.md`](docs/distribution-rework.md) records why v2.0.0 changed how this fork is built, versioned, and shipped — and the silent failures found along the way.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history, including this fork's changes.
