# Architecture

Back to the [bare-worktree README](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/README.md).

How the layout and the commands work inside. For why they work this way, see
[Decisions](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/decisions.md).

## The layout on disk

```
repo/                     # the container: holds only .git and worktrees
├── .git/                 # bare repository (core.bare = true)
│   ├── HEAD, config, objects/, refs/
│   └── worktrees/
│       ├── main/         # git dir of the main worktree: HEAD, index, logs/HEAD
│       └── feat-x/       # git dir of the feat/x worktree
├── main/                 # worktree; main/.git is a file pointing to .git/worktrees/main
└── feat-x/
```

- `.git` is a bare repository: `core.bare = true`, no index, no files checked out next to it.
- Each worktree's git dir is `.git/worktrees/<name>`. It holds that worktree's `HEAD`, `index` and reflog.
  The worktree's own `.git` is a one-line file that points there.
- The fetch refspec is `+refs/heads/*:refs/remotes/origin/*`, the same as in a normal clone.
  `git clone --bare` does not set it, so the commands do.
- All worktrees share one object store, one set of refs and one config.

## How Worktrunk config combines

**User config**, `~/.config/worktrunk/config.toml`:

- It is personal and lives outside every repo.
- It holds the layout (`worktree-path`) and other global defaults.
- `[projects."<host>/<owner>/<repo>"]` tables override settings for one repo. Keys may contain `*`
  wildcards.
- In those tables, single values such as `worktree-path` replace the global value. Hooks and aliases are
  added after the global ones.

**Project config**, `.config/wt.toml`:

- It is committed to the repo and shared with everyone who works on it.
- It holds hooks, `[list] url`, `[forge]`, aliases, and copy-ignored excludes.
- It has no `worktree-path`: the layout is a personal choice.

**Where wt reads the project config in the bare layout:**

- The container holds only `.git`, so nothing is read from there.
- wt reads `.config/wt.toml` from the current worktree. `feat-x/` reads its own copy; the container and
  `main/` read `main/.config/wt.toml`.
- The file is tracked in git, so every worktree has its own copy. A new branch starts with the version on
  the branch it was created from, and each branch can change its copy.

**The layout line.** In this layout, `{{ repo_path }}` is the bare `.git` directory, so

```toml
worktree-path = "{{ repo_path }}/../{{ branch | sanitize }}"
```

puts the worktree for `feat/x` at `repo/.git/../feat-x`, which is `repo/feat-x`.

## What each command does

### clone

`git clone-worktree <repository> [directory]`:

1. Check the arguments, then run the preflight
   ([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-clone-runs-the-preflight-before-the-destination-checks)).
2. Work out the directory: the second argument, or the name `git clone` would pick (drop trailing `/` and a
   trailing `/.git`, take the last path or `host:path` part, drop `.git`). Refuse if it is empty, `.`, `..`
   or starts with `-`, or if it already exists.
3. Create missing parent folders (as `git clone` does), then the directory. From here until the worktree
   exists, a failure (or a signal) removes the directory, but not the parents, and prints
   `removed the partial clone at <directory>`, so a retry does not stop at "already exists"
   ([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-clone-cleans-up-and-names-the-folder-like-git-clone)).
   Then `git clone --bare <repository> <directory>/.git`.
4. Set `remote.origin.fetch` to the standard refspec, then `git fetch origin`.
5. `git remote set-head origin --auto`, then read `refs/remotes/origin/HEAD` to find the default branch.
6. Make the default branch track `origin/<branch>`.
7. `git worktree add <directory>/<branch-dir> <branch>`. git creates the first checkout, so its place does
   not depend on any Worktrunk setting.
8. The [shared final steps](#shared-behaviour).

### init

`git init-worktree <directory> [--branch <name>]`:

1. Check the arguments, then run the preflight.
2. Refuse if git is older than 2.42, or if `<directory>` exists, even if it is empty.
3. Pick the branch: `--branch`, else `init.defaultBranch` from your global config, else `main`. Refuse if
   `git check-ref-format --branch` rejects it.
4. Refuse if git has no identity for the commit (`git var GIT_AUTHOR_IDENT` and `GIT_COMMITTER_IDENT`).
   Every check runs before anything is created
   ([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-init-checks-identity-and-branch-name-first)).
5. Create missing parent folders, then the directory. From here on, a failure (or a signal) removes the
   directory, but not the parents, and prints `removed the partial repository at <directory>`. Then `git init --bare -b <branch> <directory>/.git`.
6. `git --git-dir=<directory>/.git worktree add --orphan -b <branch> <directory>/<branch-dir>`.
7. An empty root commit in the new worktree, so `wt switch -c` has something to branch from. It uses
   `--no-verify`, so commit hooks do not run; `commit.gpgSign` still applies
   ([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-init-root-commit-skips-hooks-and-failures-clean-up)).
8. The [shared final steps](#shared-behaviour).

### convert

`git convert-worktree [path] [--dry-run]`. `path` defaults to the current directory, and is resolved with
`git -C <path> rev-parse --show-toplevel`, so a subfolder works.

It refuses, changing nothing, if:

- the path is not a directory, not in a git repository, or not in a working tree;
- the top level is a linked worktree, not the main worktree;
- the repo is already bare;
- the git directory is not `<top>/.git` (a separate git dir or `core.worktree` elsewhere);
- `GIT_DIR` or `GIT_WORK_TREE` is set and names a different repo or folder;
- the top level is your home directory or `/`;
- HEAD is detached, unborn, or not a local branch;
- a merge, rebase, cherry-pick, revert or bisect is in progress;
- submodules are initialised (`.git/modules` exists);
- sparse checkout is on;
- `.git/index.lock` exists (another git process is running, or one crashed);
- a linked worktree is already registered at the target folder, or the stage folder already exists;
- the repo folder, or a top-level folder in it, is not writable, so step 2 could not move everything.

Most of these were added during implementation: see the divergences
[four more convert refusals](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-four-more-convert-refusals),
[repository variables](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-repository-variables-are-cleared-or-checked),
[home directory and root](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-convert-refuses-the-home-directory-and-root) and
[movability precheck](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-message-accuracy-and-movability-precheck). The exact messages are in
[Usage](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/usage.md#git-convert-worktree).

`--dry-run` runs the preflight and these checks, prints the plan, and exits.

The steps. The stage folder sits inside the repo, so every move is a rename on the same filesystem: a large
build folder moves instantly, and modified, staged, untracked and ignored files all survive.

1. Record `git worktree list --porcelain`.
2. Move every top-level entry except `.git` into `<repo>/.convert-worktree.<pid>`. Moving first avoids a
   clash with a tracked folder that has the branch's name.
3. `git config core.bare true`, and unset `core.worktree` if it is set. When `extensions.worktreeConfig` is
   on, `core.bare = true` goes into `.git/config.worktree` instead, because in the shared config it would
   make every linked worktree bare
   ([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-convert-with-extensionsworktreeconfig)).
4. `git worktree add --no-checkout <repo>/<branch-dir> <branch>`. Then check that exactly one new entry
   appeared in `.git/worktrees`, and that it is the new worktree's git dir; otherwise stop.
5. Copy `.git/index` (and any `sharedindex.*` files of a split index) and `.git/logs/HEAD` into the new
   worktree's git dir. Move `.git/config.worktree` there if it exists. With `extensions.worktreeConfig` on,
   copy it there instead, unset `core.bare` in the copy, and replace the bare repo's file, by writing a new
   one beside it and renaming it into place, with one holding only `core.bare = true`. Check that the new
   worktree can read its index (`git ls-files --stage`), and only then remove the bare repo's index
   ([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-split-index-is-carried-over)).
6. Move the stage folder's contents, dotfiles included, into `<repo>/<branch-dir>`, and remove the stage
   folder.
7. Repair linked worktrees that were inside the old working tree (for example `.claude/worktrees/*`): map
   their recorded paths to the new location and run `git worktree repair <new paths...>`. Worktrees outside
   the repo need nothing. If the repair fails, only warn, with the command to rerun.
8. If `origin` exists and `remote.origin.fetch` is not set, set the standard refspec. A custom refspec is
   never overwritten. Then `git remote set-head origin --auto`; if that fails, only warn, so the command
   works offline.
9. Print `Converted <repo>: ...`. When linked worktrees exist outside the repo folder, print a `Hint:` line
   suggesting `wt -C <checkout> step relocate --dry-run`, which can move worktrees that sit outside the
   layout
   ([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-relocate-hint-only-when-needed)). Then the
   [shared final steps](#shared-behaviour).

**Signals.** Steps 2 to 7 are renames and small writes that take milliseconds. During them the command
ignores HUP, INT and TERM, so Ctrl-C cannot leave the files half-moved. A program started then would
inherit the ignored signals, so the git calls in those steps run no user code: `git worktree add` runs
with `-c core.hooksPath=/dev/null`, and `read-tree` and `ls-files` with `-c core.fsmonitor=false`
([re-review](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-re-review-four-follow-up-fixes)). Signals work again from step 8, where `git remote set-head` may wait on the network
([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-convert-steps-2-to-7-ignore-signals)).

**Failure recovery.** If a step from 2 to 6 fails, the command stops and prints exact recovery commands for
the step it reached: where the files are, how to move them back, `git config core.bare false` (or the
`config.worktree` equivalent), and `rm -rf` of only the `.git/worktrees/<name>` entry this run created. It
never runs `git worktree prune`, which would also drop the records of worktrees that are only out of reach
for the moment ([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-recovery-without-prune)). There is no automatic rollback.
If a step from 7 on fails, every file is already in place, so it prints the follow-up commands instead:
`git worktree repair ...` at step 7, or at step 8 the refspec (when it was not yet written) and
`git remote set-head origin --auto` (when `origin` has a URL) ([re-review](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-re-review-four-follow-up-fixes))
([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-convert-failure-handling-by-step)). The manual version of these steps, and how
to undo them, is in
[Usage](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/usage.md#convert-an-existing-clone).

### switch

`git switch-worktree` runs the preflight, then `exec wt switch "$@"`. It parses nothing itself. Arguments,
output and exit code are wt's.

## Repository variables

`git --git-dir=... <verb>` exports `GIT_DIR` to the subcommand, and a shell may have it exported. Left in
place, it would point every git call in the scripts at another repository.

- clone and init unset `GIT_DIR`, `GIT_WORK_TREE` and the other repository-location variables
  (`GIT_COMMON_DIR`, `GIT_INDEX_FILE`, `GIT_OBJECT_DIRECTORY` and so on) before doing anything. `-c`
  settings stay.
- convert unsets them too, but first remembers `GIT_DIR` and `GIT_WORK_TREE`. The repo is always the
  `[path]` argument (default: the current directory); `GIT_DIR` never selects it. If either variable was
  set, it must name that repo, or convert refuses. So `git --git-dir=<repo>/.git convert-worktree <repo>`
  converts `<repo>`, and the same command without `<repo>`, run outside it, is refused.

See the [divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-repository-variables-are-cleared-or-checked) for why.

## Shared behaviour

- **Preflight.** `command -v wt`, right after the arguments are checked. If wt is missing, print the
  preflight message (see
  [Usage](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/usage.md#preflight)) and exit 1
  before touching anything. `git bare-worktree` runs the same check before it dispatches, and then checks
  that the verb script is on `PATH`. `git bare-worktree config-example` does not need wt, and neither does
  `git bare-worktree <action> -h`, except `switch -h`, which is wt's help
  ([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-dispatcher-help-without-wt)).
- **Folder names.** The checkout folder is `<container>/<sanitized branch>`. Names are sanitized the way
  wt's `{{ branch | sanitize }}` filter does it: `/` and `\` become `-`. Only the folder name changes; the
  branch keeps its real name. `feature/test-feature` lives in `feature-test-feature/`.
- **Final `wt switch`.** `wt -C <container> switch <branch> --no-cd --no-hooks`. On a first interactive run
  with no layout configured, Worktrunk offers to save one. With `worktree-path` already set, the call does
  nothing visible. If it fails, the command prints a warning and still exits 0, because the git work is done.
- **zoxide.** If `command -v zoxide` succeeds, run `zoxide add <checkout>` after the git work. Its failure
  only warns. Without zoxide, this step is skipped quietly. The commands do this themselves because
  `--no-hooks` stops the `post-start` hook from running for the first checkout.
- **Output.** A blank line, then `Checkout: <checkout>` and
  `Next:     cd <checkout>   # or: wt -C <container> switch <branch>`, with
  `   |   z <container-name> <branch-dir>` appended when zoxide is on `PATH`. Words on the `Next:` line are
  single-quoted only when they need it. See
  [Usage](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/usage.md#output).

`git switch-worktree` shares only the preflight. All of its other output is wt's.

All scripts are POSIX `sh` with `set -eu`.

## How the dispatcher and alias fit together

```
git bwt <action> ...
  └─ exec git bare-worktree "$@"
       └─ preflight (skipped for <action> -h), then exec git-<action>-worktree "$@"
```

- `git-bwt` is two lines, in the same form as a portmanteau. Preflight, usage and exit codes all come from
  `git-bare-worktree`, so the two cannot drift apart.
- `git-bare-worktree` needs the four verb scripts on `PATH`. `git-bwt` needs `git-bare-worktree`.
- `git-bare-worktree config-example [--project]` prints the samples from heredocs inside the script (see
  [Packaging](#packaging)).

## Packaging

The repo keeps the scripts in `bare-worktree/`. `scripts/build-dist.sh` builds one release tarball that both
mise and Homebrew install:

```
bin/                               git-* + portmanteaus/* + bare-worktree/git-*   (flattened)
docs/
share/git-toolbelt/bare-worktree/  README.md  config.toml.example  wt.toml.example  docs/*.md
README.md CHANGELOG.md LICENSE
```

Where the shared files end up:

| Install | Path |
|---|---|
| Tarball | `share/git-toolbelt/bare-worktree/` |
| mise | `$(mise where github:sdthach/git-toolbelt)/share/git-toolbelt/bare-worktree/` |
| Homebrew | `$(brew --prefix)/share/git-toolbelt/bare-worktree/` (the formula's `pkgshare`) |

`docs/plans/` is not shipped. It stays in the repo.

**Why the samples are also heredocs.** Under mise, commands run through shims, so a script cannot reliably
find files next to itself. `git bare-worktree config-example` therefore prints copies kept inside the
script. The test suite checks that they are byte-identical to the two `.example` files.

Worktrunk is not a packaging dependency. The Homebrew formula has no `depends_on`; its caveats say the
commands need Worktrunk.

## Tests

`scripts/test-bare-worktree.sh` runs the commands from `bare-worktree/` against throwaway repos.

- **Controlled `PATH`.** Reordering `PATH` is not enough: git and a distro-packaged zoxide can share
  `/usr/bin`, and CI has no zoxide at all. So each case builds a
  throwaway bin folder with links to only the tools it needs (git, sh, the coreutils it calls, and the stubs
  or real tools for that case), and sets `PATH` to that folder alone. Results are the same on every machine.
- **Isolation.** `HOME` and `XDG_CONFIG_HOME` point into the throwaway folder, git's system config is off
  (`GIT_CONFIG_NOSYSTEM`), and zoxide's data folder is a scratch one, so the tests never read or change
  your own git, wt or zoxide config.
- **The wt stub.** A fake `wt` appends its arguments to `$WT_STUB_LOG` and exits with
  `${WT_STUB_EXIT:-0}`. Each case checks the log.
- **Failure injection.** Cases that make a convert step fail call `git-convert-worktree` directly, not
  through `git convert-worktree`, because git puts its own exec-path ahead of `PATH`
  ([divergence](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-test-isolation-and-failure-injection)).
- **What it covers:**
  - clone: the bare `.git`, the refspec, the tracking branch and the checkout;
  - init: a bare `.git`, a `main/` worktree and one commit, and that `init.defaultBranch` is respected;
  - convert: modified, staged, untracked, ignored and dot files survive (`git status --porcelain=v2` is the
    same before and after); a tracked top-level `main/` folder does not collide; the upstream and the HEAD
    reflog are the same before and after; an outside linked worktree still works; a nested linked worktree
    is repaired; `extensions.worktreeConfig` and a split index are handled; a matching `GIT_DIR` works and a
    different one is refused; INT and HUP during the moves do not stop it halfway; a folder it cannot move
    and `$HOME` are refused up front; a custom `remote.origin.fetch` is left alone; every refusal (linked
    worktree, bare, detached, unborn, merge, submodule, sparse, no repo); and a failure at step 4, or at
    step 6 with `worktreeConfig`, prints recovery commands that restore the clone exactly, without touching
    a worktree that is out of reach;
  - clone and init clean up after a failure; init ignores an exported `GIT_DIR` and runs no commit hooks;
  - zoxide: with a stub, clone, init and convert call `zoxide add <absolute checkout>` and print the `z`
    hint; without zoxide there is no error and no hint; a failing stub only warns;
  - wt: a failing `wt switch` only warns; with no wt, every command fails the preflight and leaves no files;
  - dispatcher: `git bare-worktree <action>` and `git bwt <action>` match the verb; `git bwt` alone exits 2
    and `git bwt -h` exits 0, both with the `git bare-worktree` usage; `git switch-worktree -c x --no-cd`
    reaches wt as exactly `switch -c x --no-cd`, with wt's exit code;
  - samples: both `config-example` outputs are byte-identical to their files;
  - docs: every `https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/...` link points at a file
    in the working tree, and every `#anchor` matches a heading in it (without network). `docs/plans/` is
    left out, because it is a frozen record.
- **Real wt.** With `TOOLBELT_TEST_REAL_WT=1`, it also checks that the real wt parses both samples, as
  shipped and with every commented setting uncommented, and that a project file copied from
  `wt.toml.example` into a worktree's `.config/wt.toml` shows up in `wt config show`.

`scripts/smoke-test.sh` (run by CI) checks the built tarball: the six commands resolve from `bin/`, no
docs or samples land in `bin/`, the `share/` files are present, and there is no `plans/` folder in `share/`.
