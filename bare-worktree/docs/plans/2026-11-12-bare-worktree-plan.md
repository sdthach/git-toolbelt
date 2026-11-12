# Plan: bare-worktree commands for git-toolbelt

Back to the [bare-worktree README](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/README.md).

| | |
|---|---|
| Created | 2026-11-12T12:13-05:00 |
| Approved | 2026-11-12T15:56-05:00 |
| Implemented | 2026-11-12T17:09-05:00 (gates passed on feat/bare-worktree; not yet merged or released) |
| Status | Frozen record. Later changes are in [divergences](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md) |

Original title: an opinionated `bare-worktree/` command set for git-toolbelt, a Worktrunk tutorial, and converting lean-ctx

## Context

You want every repo to use the Worktrunk "bare" layout: `<repo>/.git` is a bare repo, and each branch is a sibling
worktree (`<repo>/main`, `<repo>/feature-x`). You want two ways to get there:
- by hand, with `git` and `wt` commands in sequence;
- with commands that feel like native `git` verbs.

Both have to work for existing clones (converted in place) and for new repos (cloned from a remote, or started
from scratch). The commands are added to your git-toolbelt fork, and a tutorial explains how to set up Worktrunk properly.

**Current state:**

wt:
- wt 0.80.0 is installed via cargo, and its shell integration is in `~/.bashrc` and `~/.zshrc`. fzf 0.44.1 and zoxide 0.9.3
  come from apt and aren't set up in the shell. All three move to mise (see "Tool installs").
- `~/.config/worktrunk/config.toml` already sets `worktree-path = "{{ repo_path }}/../{{ branch | sanitize }}"`.
- Other repos on the machine already use the layout.

Distribution:
- git-toolbelt ships through **both mise and Homebrew** from one release tarball.
- v2.0.1 assets are live (the tarball and `.sha256` both return 200).
- `sdthach/homebrew-tap` points at the v2.0.1 tarball.
- You have it installed via mise (`github:sdthach/git-toolbelt` 2.0.1).

git-toolbelt work in progress:
- The repo is on local-only branch `feature/wt-clone`, which was never pushed.
- It holds **staged, uncommitted** work: `wt-clone`, `git-clone-worktree` at the repo root, doc edits, and
  `scripts/test-clone-worktree.sh`.
- A stale `~/.local/bin/wt-clone` is also installed on this machine.

**Your decisions:**

Commands:
- Native git verbs, plus a `git bare-worktree` dispatcher with a short alias `git bwt`.
- Drop the `wt-*` forms.
- Put the commands in a `bare-worktree/` folder, installed the same way as `portmanteaus/`.
- **No auto-cd.** Like `git clone`, the commands don't change your directory. The docs tell you to `cd` or use
  `wt switch`. Worktrunk's shell integration is the only thing that can change the shell's directory; no git
  subcommand can.
- **A convenience `git switch-worktree`** that passes everything straight to `wt switch`. It is subject to the same
  limit: it creates or selects worktrees, but it can't change the shell's directory, because wt only does that
  when it's invoked through its own shell function. The docs say so plainly.
- Preflight with a clear message when `wt` is missing.
- `convert` refuses when HEAD is detached. A failing final `wt switch` only prints a warning.
- **Moving between worktrees uses zoxide and fzf** (`z`, `zi`) or wt's picker, all optional. Clone, init and convert
  run `zoxide add` on their first checkout when zoxide is installed. `config.toml.example` ships optional zoxide hooks.
  **No custom tab completion.** `wt switch <TAB>`, wt's picker, `z` and `zi` cover it, and git already completes
  the `git-*` command names.

Files and docs:
- A short README in the folder, plus `bare-worktree/docs/`: getting started, usage, architecture, decisions and
  trade-offs, and gotchas.
- Ship both Worktrunk sample configs, following Worktrunk's own naming: `config.toml.example` (user config) and
  `wt.toml.example` (project config).

Rollout:
- Convert `~/repos/lean-ctx` as the final step.
- Rename the branch to `feat/bare-worktree`. Nothing gets committed unless you ask.

## How Worktrunk config works (this drives the two examples and `docs/architecture.md`)

- **User config**, `~/.config/worktrunk/config.toml`:
  - It's personal and lives outside every repo.
  - It holds the layout (`worktree-path`) and other global defaults.
  - `[projects."<host>/<owner>/<repo>"]` tables override settings per repo, and keys may contain `*` wildcards.
  - In those tables, single values such as `worktree-path` replace the global value. Hooks and aliases are added
    after the global ones.
- **Project config**, `.config/wt.toml`:
  - It's committed to the repo and shared with teammates.
  - It holds hooks, `[list] url`, `[forge]`, aliases, and copy-ignored excludes.
  - It has **no `worktree-path`**: the layout is a personal choice.
- **Where wt reads the project config in the bare layout**, checked on an existing bare-layout repo:
  - The container holds only `.git`, so nothing is read from there.
  - wt reads `.config/wt.toml` from the current worktree: `feature-aws-hosting/` reads its own copy, and the
    container or `main/` reads `main/.config/wt.toml`.
  - The file is tracked in git, so every worktree has a copy. A new branch inherits main's version, and each
    branch can change its own copy.

## `bare-worktree/` folder

| File | Invoked as | Purpose |
|---|---|---|
| `git-clone-worktree` | `git clone-worktree <url> [dir]` | Moved from the root. It takes over the body of the staged `wt-clone`, and `wt-clone` is deleted |
| `git-init-worktree` | `git init-worktree <dir> [--branch <name>]` | Start a brand-new repo |
| `git-convert-worktree` | `git convert-worktree [path] [--dry-run]` | Convert an existing normal clone in place |
| `git-switch-worktree` | `git switch-worktree [wt switch args…]` | Convenience passthrough: wt preflight, then `exec wt switch "$@"`, with no argument parsing of its own. Examples: `git switch-worktree -c feat/x`, `git switch-worktree ^`, `git switch-worktree` (opens wt's picker) |
| `git-bare-worktree` | `git bare-worktree clone\|convert\|init\|switch …` and `git bare-worktree config-example [--project]` | The dispatcher (`exec git-<action>-worktree "$@"`) and the sample printer |
| `git-bwt` | `git bwt …` | Short alias, two lines, in the same form as a portmanteau: `exec git bare-worktree "$@"`. Preflight, usage and exit codes all come from `git-bare-worktree`, so they can't drift |
| `README.md` | n/a | Short landing page: what the layout is, the commands, a quick start, links into `docs/` |
| `docs/*.md` | n/a | `getting-started.md`, `usage.md`, `architecture.md`, `decisions.md`, `gotchas.md` (see "Docs") |
| `docs/plans/` | n/a | The approved plan (redacted) and the record of later decisions and divergences. Repo only, not shipped |
| `config.toml.example` | n/a | **User** config sample: the bare-layout `worktree-path` with an explanation, a commented `[projects]` per-repo override, a commented zoxide hook block, and commented optional settings |
| `wt.toml.example` | n/a | **Project** config sample for `<worktree>/.config/wt.toml`: commented hooks (for example `pre-start = "mise trust"`), `[list] url`, and copy-ignored excludes. Its header says it is committed and read per worktree |

### Shared behaviour

All scripts are POSIX `sh` and use `set -eu`. Shared behaviour:

- **Help and usage:**
  - Every script handles `-h` and `--help` the way `git-toolbelt` does: print usage and exit 0.
  - Usage lines use the `git <verb>` form, for example `usage: git clone-worktree <repository> [directory]`. The
    staged `wt-clone` prints `usage: wt clone …`, and that text is rewritten when the body moves.
  - `git bare-worktree` with no action or an unknown action prints usage to stderr and exits 2.
  - `git-switch-worktree` doesn't parse anything itself, so `-h` goes straight to `wt switch -h`.
  - `docs/usage.md` and `docs/gotchas.md` note that git turns `git <verb> --help` into `git help <verb>`, which prints "No manual entry".
    Use `-h` instead. (Checked: `git toolbelt --help` → "No manual entry for git-toolbelt".)

- **Preflight, before touching anything.**
  - `command -v wt`. If it's missing, exit 1 with:
    ```
    git <verb>: Worktrunk (wt) is required but was not found on PATH.
      Install: https://github.com/max-sixty/worktrunk#install
      Setup:   https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/getting-started.md#setting-up-worktrunk
    ```
  - `git bare-worktree` runs the same check before dispatching.
  - `git bare-worktree config-example` doesn't need wt.
  - `git init-worktree` also checks for git 2.42 or later, which `worktree add --orphan` needs.
- **Checkout directory:** `<container>/<sanitized branch>`.
  - The scripts sanitize names the same way as wt's `{{ branch | sanitize }}`: `/` and `\` become `-`.
  - Only the directory name changes; the git branch keeps its real name. For example, `feature/test-feature`
    lives in `<container>/feature-test-feature/` but stays `feature/test-feature` in git (checked on an existing
    bare-layout repo: branch `feature/aws-hosting` → `feature-aws-hosting/`).
  - `docs/gotchas.md` notes one consequence: `feature/x` and `feature-x` map to the same directory, so wt refuses the
    second unless you choose a different path.
- **Final `wt switch`:**
  - The command is `wt -C <container> switch <branch> --no-cd --no-hooks`. It keeps `-C <container>`, as
    `wt-clone` does.
  - Its purpose: on a first interactive run with no layout configured, Worktrunk offers to save one. With your
    global `worktree-path` set, the call does nothing.
  - If it fails, the script **prints a warning and still exits 0**, because the git work is already done.
- **zoxide registration (optional):**
  - If `command -v zoxide` succeeds, run `zoxide add <checkout>` after the git work. Its failure only warns.
  - If zoxide is absent, skip this quietly. zoxide is never required.
  - Why the scripts do it themselves: they pass `--no-hooks`, so the `post-start` hook (see below) doesn't run for
    this first checkout.
- **Last lines of output**, which replace auto-cd:
  ```
  Checkout: <path>
  Next:     cd <path>        # or: wt -C <container> switch <branch>   |   z <repo> <branch-dir>  (zoxide; both words narrow the match, since `main` exists in every repo)
  ```
  The `z` hint appears only when zoxide is on PATH.

The final `wt switch` and the `Checkout:`/`Next:` lines apply to clone, init and convert. `git switch-worktree`
shares only the preflight; all other output is wt's own.

### `git switch-worktree`

- Preflight, then `exec wt switch "$@"`. Arguments, exit code and output all come from wt unchanged.
- **No directory change.** When run as a git subcommand, wt's shell function isn't involved, so the shell stays
  where it was. wt prints the worktree path along with its usual hint.
- `docs/usage.md` is explicit:
  - use `git switch-worktree` to create or prepare worktrees from git muscle memory, or in scripts;
  - to actually move into a worktree, use `wt switch` (with shell integration) or `cd`.
- Out of scope for now: an opt-in shell alias, `alias gsw='wt switch'`, could be mentioned as an idea, but it
  isn't shipped.
- Open check during implementation: confirm what wt (the version mise installs; 0.81.0 today) prints when shell integration isn't active, so
  `docs/usage.md` quotes it accurately.

### `git init-worktree`

1. Refuse if `<dir>` already exists, including an empty directory.
2. Pick the branch: `--branch`, else `git config --get init.defaultBranch`, else **`main`**. This is set
   explicitly because plain `git init` would fall back to `master`.
3. `git init --bare -b <branch> <dir>/.git`.
4. `git --git-dir=<dir>/.git worktree add --orphan -b <branch> <dir>/<branch-dir>`.
5. Make an empty root commit so `wt switch -c` has something to branch from. If `user.name`/`user.email` are
   unset, git fails with its normal message.

### `git convert-worktree [path] [--dry-run]`

`path` defaults to the current directory. An explicit path is treated the same way: it is resolved with
`git -C <path> rev-parse --show-toplevel`, so running from a subfolder, or passing one, works.

**Refuse, changing nothing, if:**
- the resolved top level is a linked worktree rather than the main worktree;
- the repo is already bare;
- **HEAD is detached** or unborn;
- an operation is in progress (merge, rebase, cherry-pick, revert or bisect);
- submodules are initialised (`.git/modules` exists);
- sparse checkout is on.

**`--dry-run`** runs the preflight and these checks, prints the plan, and exits.

**Steps.** The stage directory sits inside the repo, so every move is a same-filesystem rename. Even a huge
`rust/target` moves instantly, and dirty, staged, untracked and ignored files all survive.
1. Record `git worktree list --porcelain`.
2. Move every top-level entry except `.git` into `<repo>/.convert-worktree.$$`. Moving first avoids a clash with
   a tracked directory that has the branch's name.
3. `git config core.bare true`, and unset `core.worktree` if it's set.
4. `git worktree add --no-checkout <repo>/<dir> <branch>`.
5. Copy `.git/index` and `.git/logs/HEAD` into the new worktree's git dir (found with
   `git -C <repo>/<dir> rev-parse --git-dir`). Move `.git/config.worktree` there if it exists, then remove the
   bare repo's index.
6. Move the stage directory's contents, dotfiles included, into `<repo>/<dir>`, then remove the stage directory.
7. **Repair linked worktrees that were nested inside the old working tree** (for example `.claude/worktrees/*`).
   Map their recorded paths to the new location and run `git worktree repair <new paths…>`. Worktrees outside
   the repo need nothing.
8. If `remote.origin.fetch` is **unset**, set the standard refspec. A custom refspec is never overwritten.
   Then `git remote set-head origin --auto`; failure only warns, so the command works offline.
9. Run the final `wt switch` with its warning behaviour, then print a hint: `wt step relocate --dry-run` can move
   linked worktrees that sit outside the layout.

**On failure partway through:** stop and print exact recovery commands (where the files are,
`git config core.bare false`, how to move them back). There is no automatic rollback.

### `git bare-worktree` (short alias `git bwt`)

- Why this name: the earlier `git bare` was dropped because `git bare init` reads like `git init --bare`, which makes a bare
  repo with no checkout. `bare-worktree` matches the folder name. `git bwt` is the short form for typing.
  (`git wt` was ruled out: Worktrunk installs itself as `git-wt` on Windows.) Checked: no `git-bare-worktree`,
  `git-bwt` or `bwt` alias exists on this machine.
- Usage text always shows the long name, including when called as `git bwt`.

- Usage: `clone|convert|init|switch` dispatch to the matching `git-<action>-worktree` script; `config-example` prints the
  user sample, and `config-example --project` prints the project sample.
- The samples live in heredocs inside `git-bare-worktree`, because under mise shims a script can't reliably find files
  next to it. The test suite checks the output is **byte-identical** to the two `.example` files.
- The docs say `git-bare-worktree` needs the four verb scripts on PATH, and `git-bwt` needs `git-bare-worktree`.
- `docs/usage.md` says which to use day to day: the `*-worktree` verbs, or `git bwt <action>` as one short entry point.

### Moving between worktrees: zoxide + fzf (optional, documented, not required)

There is still no auto-cd. Moving into a worktree uses tools that already ship their own shell functions:
- **`z <name>` / `zi`** come from zoxide. `zi` opens an fzf picker.
- **`wt switch`** with no arguments opens wt's own interactive picker and `cd`s through its shell integration.

On this machine, zoxide and fzf are moved to mise and set up in `~/.bashrc` as part of "Tool installs".

Two pieces keep zoxide's list up to date:
- **First checkout:** the scripts' `zoxide add` (see Shared behaviour).
- **Every later worktree:** `config.toml.example` ships a commented, optional block:
  ```toml
  # Keep zoxide's list in sync with your worktrees (needs zoxide on PATH).
  # post-start  = "zoxide add {{ worktree_path }}"
  # post-remove = "zoxide remove {{ worktree_path }}"
  ```
  **Already confirmed from `wt hook --help`:**
  - user hooks need no approval;
  - `{{ worktree_path }}` is set for remove hooks (it refers to the worktree being removed);
  - variables are shell-escaped automatically, so the lines stay unquoted.

  **Still to check during implementation:**
  - that the block parses once uncommented (`wt --config … hook show`);
  - **`post-remove`:** that `zoxide remove` (on mise's zoxide 0.10) accepts a path that no longer exists. If it
    doesn't, drop the `post-remove` line, ship only `post-start`, and rely on zoxide skipping missing folders.
  - How to check: `post-*` hooks run in the background and their output goes to a log (`wt hook --help`). A
    failure never shows in the terminal, so run the hook with `wt hook post-remove --foreground`, or read the log
    found through `wt config state logs`.

`docs/getting-started.md` (setup) and `docs/usage.md` (daily flow) cover:
- `eval "$(zoxide init bash)"` in `~/.bashrc`;
- that fzf is what powers `zi`;
- enabling the hook block;
- the daily flow:
  - `wt switch -c feat/auth` `cd`s you there, so zoxide's prompt hook learns the folder;
  - `git switch-worktree -c feat/auth`, then `z auth`, works **only with the `post-start` hook enabled**, because
    `git switch-worktree` doesn't `cd`;
  - or `zi`, or a plain `wt switch`;
- a note that after `git convert-worktree`, zoxide's old entry for the repo root now points at the bare container.
  Use `z <repo> main`.

### Tab completion: none shipped (decision)

What already covers it:
- `git switch-w<TAB>`, `git bare-w<TAB>` and `git bw<TAB>` complete the command names, because git's bash completion lists `git-*`
  commands on PATH (`list-mainporcelain,others`).
- Paths fall back to file-name completion.
- Branch names: use `wt switch <TAB>` (wt's own completion), or the picker (`wt switch`, plus `--branches` /
  `--remotes`), or `z` / `zi`.

`docs/usage.md` says this in one short paragraph, and `docs/decisions.md` records why.

## Packaging and release (mise and Homebrew, one tarball)

**What stays the same:**
- `release.yml` needs no change: it calls `build-dist.sh` and copies the formula into the tap.
- There are no new release assets.

**Version:** `wt-clone` and `git-clone-worktree` were never released, so this lands as a `feat(bare-worktree): …`
commit. release-please will propose **2.1.0** (the manifest is at 2.0.1).

**Globs:** they use `bare-worktree/git-*`, never `bare-worktree/*`, because the folder also holds docs and samples.

### Tarball layout (`scripts/build-dist.sh`)

```
bin/                               git-* + portmanteaus/* + bare-worktree/git-*   (flattened, as today)
docs/
share/git-toolbelt/bare-worktree/  README.md  config.toml.example  wt.toml.example  docs/*.md   (new)
README.md CHANGELOG.md LICENSE
```

- Add `cp -p bare-worktree/git-* "$stage/bin/"` and the copy into `share/`: `README.md`, both `.example` files,
  and `docs/*.md` into `share/git-toolbelt/bare-worktree/docs/`.
- **Add `share` to the `tar` member list** (`-cf - bin docs share README.md CHANGELOG.md LICENSE`). The list is
  explicit, so without this `share/` is silently left out of the tarball.
- Drop `cp -p wt-*`, and update the layout comment.
- The archive still has more than one top-level directory, so mise's automatic `strip_components` can't kick in.
- The existing loop that checks every `bin/*` entry for an exec bit and shebang already catches a data file that
  lands in `bin/` by mistake.

### mise

- Nothing changes for users: `bin/` picks up the new commands, and `mise upgrade` installs 2.1.0.
- The samples are installed under `$(mise where github:sdthach/git-toolbelt)/share/…`, but `git bare-worktree config-example` is the easier way to get them.
- For Worktrunk itself, the docs recommend the registry shortname `mise use -g worktrunk` (aqua backend), then `brew install worktrunk` and
  `cargo install worktrunk`.
- Dev `mise.toml`:
  - `_.path = [".", "portmanteaus", "bare-worktree"]`;
  - lint at full severity: `shellcheck -s sh portmanteaus/* bare-worktree/git-* scripts/*.sh git-toolbelt`.

### Homebrew (`packaging/git-toolbelt.rb`, copied wholesale into the tap at release)

- **Stable:**
  - keep `bin.install Dir["bin/*"]`;
  - add `pkgshare.install "share/git-toolbelt/bare-worktree"`.
- **`--HEAD`:**
  - add `bin.install Dir["bare-worktree/git-*"]`;
  - add `(pkgshare/"bare-worktree").install` for the README and both `.example` files, and
    `(pkgshare/"bare-worktree/docs").install Dir["bare-worktree/docs/*.md"]`.
- **Worktrunk stays optional.** No `depends_on`. Instead, a `caveats` block covers:
  - that the bare-worktree commands need Worktrunk (`brew install worktrunk`, plus the GitHub link);
  - `git bare-worktree config-example`;
  - the pkgshare path.
- **`test do`:**
  - `bin/"git-bare-worktree"`, `bin/"git-bwt"` and the pkgshare samples exist;
  - `git bare-worktree config-example` succeeds;
  - with `PATH` set explicitly to `bin` and the system dirs (no wt), `git clone-worktree` fails with the
    preflight message.
- Update the count comment.
- Check the syntax with `ruby -c` if Ruby is available. brew isn't installed here, so there's no local
  brew-install check.

### CI and smoke test (`scripts/smoke-test.sh`, run by `ci.yml` through `mise run smoke`)

- The six commands (four verbs, `git-bare-worktree`, `git-bwt`) resolve from the extracted `bin/`, and
  `git bwt config-example` succeeds from there.
- No `wt-*`, `README.md` or `*.example` files end up in `bin/`.
- The `share/git-toolbelt/bare-worktree/` files are present, including the five `docs/*.md`.
- It runs the renamed `scripts/test-bare-worktree.sh`.

### Repo housekeeping

- `.github/workflows/upstream-sync.yml`: add `bare-worktree` to its "fork-only files" text.
- `docs/maintaining-the-fork.md` and `docs/distribution-rework.md`:
  - note that `share/` is now in the shipped layout;
  - note that `bare-worktree/` is fork-only, like `portmanteaus/`;
  - update the lint description.
- `PUBLISHING.md`: update it only if it describes the archive layout.

## Docs

### `bare-worktree/README.md` and `bare-worktree/docs/`

The folder README is a short landing page. The detail lives in `bare-worktree/docs/`, one file per question.
Each topic lives in exactly one file, and other files link to it rather than repeat it.

**Rules for every file:**
- It starts with `Back to the [bare-worktree README](…).`, the same opening the root `docs/*.md` use
  (for example "Back to the [README](../README.md)").
- Links use absolute GitHub URLs (`https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/…`), so the
  copies under the tarball's `share/` and Homebrew's `pkgshare` still work.

| File | Purpose | Contents |
|---|---|---|
| `README.md` | Landing page | What the layout is (a tree of `<repo>/.git` plus `<repo>/main`, `<repo>/feat-x`), three reasons to use it (parallel branches and agents, no stash juggling, one shared object store), the six commands in one table, a five-line quick start, and links to the docs below |
| `docs/getting-started.md` | Zero to a first worktree in about 5 minutes | **Install** (`mise use -g worktrunk fzf zoxide`; alternatives `brew install worktrunk` or `cargo install worktrunk`, and other options in Worktrunk's README at https://github.com/max-sixty/worktrunk#install; Worktrunk isn't packaged for apt). **Setting up Worktrunk** (the anchor the preflight message links to): `wt config shell install`, restart the shell, `type wt`; find the config with `wt config show`, create it with `wt config create` if missing; merge the `worktree-path` line from `git bare-worktree config-example` into it (no `>` redirect, so nothing is overwritten). **Optional zoxide and fzf**: `eval "$(zoxide init bash)"` as the last line, `z`/`zi`, the hook block, and the init order (mise, then wt, then zoxide). **First repo**: one of `git clone-worktree <url>`, `git init-worktree <dir>` or `git convert-worktree`, then `cd` into the printed `Checkout:` path. **Next steps**: links to usage and gotchas |
| `docs/usage.md` | Day-to-day reference | **Commands reference**: the four verbs, `git bare-worktree` and `git bwt`, `-h` (and why `--help` says "No manual entry"), arguments, output, exit codes, and every refusal and failure message. **Getting into a worktree**: `cd <path>` or `wt switch <branch>`; there is no auto-cd, matching `git clone`; `git switch-worktree` doesn't cd either, with the exact message wt prints. **Moving around**: `z <repo> <branch-dir>`, `zi`, `wt switch`'s picker; tab completion: none shipped, use `wt switch <TAB>`, the picker or `z`/`zi`. **Daily workflow**: `wt switch -c` / `git switch-worktree -c`, `wt switch ^`, `wt list`, `wt remove`, `wt step relocate`, `wt step prune`. **Manual recipes** using only `git` and `wt`, copy-pasteable in order: (a) clone a remote; (b) start a brand-new repo, then later `git remote add` and `git push -u` (in a bare repo, `remote add` sets the normal refspec); (c) convert an existing clone, with lean-ctx as the worked example, including how to undo it and the nested-worktree repair. **Config**: per-repo overrides through `[projects."…"]`, the project config via `wt config create --project` or `git bare-worktree config-example --project`. **Standalone install**: install all six scripts together (`install -m 755 bare-worktree/git-* ~/.local/bin/`); if you once installed `wt-clone` by hand, remove it |
| `docs/architecture.md` | How it works inside | **The layout on disk**: `.git` is bare (`core.bare = true`), each worktree's git dir is `.git/worktrees/<name>`, and the fetch refspec. **How Worktrunk config combines**: the user config and its `[projects]` tables, the project config, and the bare-layout rule that each worktree reads its own `.config/wt.toml` (from "How Worktrunk config works" above). **What each command does, step by step**: clone, init, the nine convert steps with its refusals and failure recovery, and switch. **Shared behaviour**: preflight, name sanitizing, the final `wt switch --no-cd --no-hooks`, `zoxide add`, the `Checkout:`/`Next:` output. **How the dispatcher and alias fit together** (`git bwt` → `git bare-worktree` → `git-<action>-worktree`). **Packaging**: where the files land in the tarball (`bin/`, `share/git-toolbelt/bare-worktree/`), under mise and under Homebrew `pkgshare`, and why the samples are also heredocs. **Tests**: what `scripts/test-bare-worktree.sh` covers, the wt stub, the controlled PATH, and the real-wt variant |
| `docs/decisions.md` | Decisions and trade-offs | One short entry per decision: **Decision**, **Why**, **Trade-off / what we gave up**, **Revisit if**. Entries: (1) no auto-cd: a git subcommand can't change the shell's directory, matching `git clone`; (2) `*-worktree` verbs instead of `wt-*` commands, so they read as native git; (3) the dispatcher is `git bare-worktree` with alias `git bwt`, not `git bare` (`--bare` confusion) or `git wt` (Worktrunk's Windows name); three ways to call one command is accepted; (4) Worktrunk is required at runtime but optional in packaging: preflight plus Homebrew caveats, no `depends_on`; (5) `git switch-worktree` is a pure passthrough, with no parsing of its own; (6) the samples are shipped twice, as files and as heredocs, because mise shims can't find files next to a script, with a test keeping them identical; (7) folder names are sanitized the way wt does, while branch names are kept; (8) the first checkout skips wt hooks (`--no-hooks`), so the scripts run `zoxide add` themselves; (9) convert refuses rather than guesses (detached HEAD, operations in progress, submodules, sparse checkout), and has no automatic rollback, only printed recovery steps; (10) a failing final `wt switch` only warns, because the git work is done; (11) no custom tab completion: wt's completion, the picker, `z` and `zi` cover it; (12) zoxide and fzf are optional, and fzf's key bindings stay off because of atuin's Ctrl-R; (13) mise is the recommended install for wt, fzf and zoxide (checksum-verified aqua binaries, one tool manager) |
| `docs/gotchas.md` | Things that surprise you | Absolute paths change after convert: IDE projects, cargo rebuilding `target/`, Claude Code memory keyed by path (and the trust prompt, and `--resume` history); running editors, agents and daemons whose root was the old path; zoxide's old entry for the repo root now points at the bare container (use `z <repo> main`); submodules aren't supported by convert; `feature/x` and `feature-x` map to the same folder; wt hooks are skipped on the first checkout; `git <verb> --help` says "No manual entry" (use `-h`); `git switch-worktree` doesn't cd; `post-*` hooks run in the background, so their failures only show in the log (`wt config state logs`); **works with atuin**: the Ctrl-R conflict with fzf's key bindings and why `zoxide init` goes last |

**Checks on the docs** (part of the gates):
- every `https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/…` link points at a file that exists in
  the working tree, and every `#anchor` matches a heading in it. The preflight's
  `getting-started.md#setting-up-worktrunk` is the important one. The test script checks this with `grep`, so it
  needs no network;
- the commands and flags quoted in `usage.md` match each script's `-h` output.
- `docs/plans/` is left out of the link check. The plan copy is a frozen record, and it mentions names that
  changed later (for example `git bare`).

### `bare-worktree/docs/plans/`: the plan and what changed after it

A record of how the feature was designed, the same idea as the repo's existing `docs/distribution-rework.md`
("This document is the *why*").

| File | Purpose |
|---|---|
| `docs/plans/2026-11-12-bare-worktree-plan.md` | A copy of this plan as approved, with personal details removed (see below) |
| `docs/plans/2026-11-12-bare-worktree-divergences.md` | Decisions made after the plan was approved, and every place the implementation differs from the plan, with the reason |

The date prefix is the day the plan was created, so later plans sort in order.

**Plan copy header:**
```markdown
# Plan: bare-worktree commands for git-toolbelt

Back to the [bare-worktree README](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/README.md).

| | |
|---|---|
| Created | 2026-11-12T12:13-05:00 |
| Approved | <date and time you approve it in plan mode> |
| Implemented | <date the gates pass on feat/bare-worktree> |
| Status | Frozen record. Later changes are in [divergences](…/2026-11-12-bare-worktree-divergences.md) |
```
- **Created** comes from the first write of this plan file in the session transcript (`2026-11-12T17:13:29Z`).
  The file's own timestamp can't be used, because every edit replaces the file.
- **Approved** is filled in when you approve the plan. **Implemented** is filled in when the gates pass (step 4 of
  "Execution order").
- After that, the body is never edited again. Every later change goes in the divergences file.

**Redaction** (git-toolbelt is public; your decision):
- the design sections stay verbatim;
- home paths become `~`, and your username is removed;
- the machine-only sections are each replaced by a one-line note, "Local setup steps on the author's machine;
  not part of the design". These are: "Tool installs on this machine" (including the `~/.bashrc` diff and line
  numbers; the generic atuin advice is already in `gotchas.md`), "PATH in this Claude session", "Final steps on
  this machine" (the lean-ctx conversion and Claude Code memory), and the matching steps in "Execution order"
  and "Verification";
- the other repo names in "Current state" are removed;
- check before commit: a grep of `docs/plans/*.md` for home paths, the username, `.bashrc` line numbers,
  Claude Code project paths and other repo names finds nothing.
  finds nothing.

**Divergences file:**
```markdown
# Bare-worktree: decisions and divergences after the plan

Back to the [plan](…/2026-11-12-bare-worktree-plan.md) · [decisions](…/decisions.md)

## Decisions made after the plan
### YYYY-MM-DD: <title>
- **Decision:**
- **Why:**
- **Affects:** <files or docs changed>

## Where the implementation diverged from the plan
### YYYY-MM-DD: <title>
- **Plan said:** <quote, with the plan section>
- **Did instead:**
- **Why:** <what was found, with evidence such as a command and its output>
- **Affects:**
```
- It is created at the start of implementation with both sections empty. It is updated as each divergence happens,
  not reconstructed at the end.
- The plan's open checks become entries once resolved: the message wt prints without shell integration, whether
  `zoxide remove` accepts a missing path (and whether `post-remove` stays), zoxide 0.10's doctor warning, and
  `FZF_CTRL_R_COMMAND`.
- Divergences found while converting lean-ctx are recorded here only if they affect the design (for example, a
  convert bug), and described without the machine details.
- `docs/decisions.md` always describes the current state. When a divergence changes a decision, that entry is
  updated and links to the divergence entry.

**Not shipped:** `docs/plans/` stays in the repo only. The tarball's `share/` copy and Homebrew's `--HEAD`
install use `bare-worktree/docs/*.md`, which doesn't match files in subfolders, so the plans are left out. The smoke
test checks that no `plans/` folder ends up in `share/`.

### Other docs

- `docs/commands.md`: remove the staged `git clone-worktree` / `wt clone` sections and the table-of-contents line,
  and link to the folder README and `bare-worktree/docs/usage.md` instead.
- `README.md`:
  - layout tree: add `bare-worktree/` and remove `wt-clone`;
  - add a "Bare-worktree commands" `<details>` section like the portmanteaus one;
  - remove the staged "Everyday" line;
  - update the count: `ls git-* portmanteaus/* bare-worktree/git-* | wc -l`, expected 63 + 14 + 6 = 83.
- `docs/install.md`:
  - update the count;
  - the Worktrunk prerequisite line now covers only the bare-worktree commands, lists mise (recommended), brew
    and cargo with a link to Worktrunk's other install options, and links to `bare-worktree/docs/getting-started.md`;
  - in both the mise and the brew sections: where the samples land, plus `git bare-worktree config-example`;
  - the dev-environment note mentions `bare-worktree/` on PATH;
  - replace the "Standalone Worktrunk clone extension" section with a pointer to `bare-worktree/docs/usage.md`
    (standalone install).

## Tests: `scripts/test-bare-worktree.sh`

This is a rename of the uncommitted `test-clone-worktree.sh`. It resolves the commands from `bare-worktree/` and keeps
the existing clone assertions.

**Controlled PATH.** The "no wt" and "no zoxide" cases can't just reorder PATH: git and the apt zoxide both live in
`/usr/bin`, and CI has no zoxide at all. So the test builds a throwaway bin directory containing links to only
the tools it needs (`git`, `sh`, the coreutils it calls, plus the stubs or real tools for that case) and sets
`PATH` to that directory alone. The results are then the same on this machine and on CI.

**The fake `wt` stub is rewritten.** It appends its arguments to `$WT_STUB_LOG` and exits with
`${WT_STUB_EXIT:-0}`, and each test checks the log. The old stub hard-checked for exactly 6 arguments, which
rejects `switch -c x --no-cd` and can't be made to fail on purpose.

New cases:

**convert:**
- a modified, a staged, an untracked and an ignored file all survive (`git status --porcelain=v2` is identical before and after);
- a tracked top-level `main/` directory doesn't collide;
- an outside linked worktree still works;
- a linked worktree nested in the repo is repaired;
- a custom `remote.origin.fetch` is left untouched;
- refusals: linked worktree, bare repo, detached HEAD, merge in progress, submodule.

**init:**
- the result is a bare `.git`, a `main/` worktree and one commit;
- `init.defaultBranch` is respected.

**zoxide:**
- with a stub `zoxide` on PATH, clone, init and convert each call `zoxide add <checkout>` with the absolute
  checkout path, and the `Next:` line includes the `z` hint;
- with no zoxide on PATH, there's no error, no zoxide output and no `z` hint;
- a stub `zoxide` that fails only produces a warning, and the command still exits 0.

**wt behaviour:**
- with a stub `wt switch` that fails, the command warns and exits 0;
- with no wt on PATH, every verb, `git bare-worktree` and `git bwt` included, fails the preflight and leaves no
  files behind.

**git bare-worktree / git bwt:**
- `git bare-worktree <action>` and `git bwt <action>` both give the same result as the verb;
- `git bwt` with no action, and `git bwt -h`, print the `git bare-worktree` usage (exit 2 and 0 respectively);
- `git switch-worktree -c x --no-cd` reaches the stub `wt` as exactly `switch -c x --no-cd`, and wt's exit code comes back unchanged;
- both `config-example` outputs are byte-identical to their files.

**With `TOOLBELT_TEST_REAL_WT=1`** (real wt):
- `wt --config bare-worktree/config.toml.example config show` parses;
- a project file copied from `wt.toml.example` into a worktree's `.config/wt.toml` shows up in `wt config show`.

## Execution order

Local setup steps on the author's machine; not part of the design.

1. Local setup steps on the author's machine; not part of the design.
2. Rename the git-toolbelt branch to `feat/bare-worktree`.
3. First, write `docs/plans/2026-11-12-bare-worktree-plan.md` (the redacted copy, with Created and Approved
   filled in) and the empty divergences file. Then implement the `bare-worktree/` folder, the packaging changes,
   the docs and the tests, adding a divergences entry whenever the work differs from the plan.
4. Gates:
   - `mise run lint`;
   - the test script, with the stub and with real wt;
   - `mise run smoke`;
   - the manual checks;
   - the redaction grep on `docs/plans/`;
   - then fill in **Implemented** in the plan copy.
5. Local setup steps on the author's machine; not part of the design.
6. Local setup steps on the author's machine; not part of the design.
7. Local setup steps on the author's machine; not part of the design.

## Tool installs on this machine, all through mise (done first, before implementation)

Local setup steps on the author's machine; not part of the design.

## Final steps on this machine

Local setup steps on the author's machine; not part of the design.

## Review status

- **First review:** 17 findings. All are resolved; #11 and #12 dropped out when auto-cd was removed.
- **Second review:** 11 findings, all applied:
  - the `tar` member list includes `share`;
  - a temporary PATH entry bridges the gap until the release;
  - the test stub is rewritten;
  - the zoxide flow, its hook checks and the old repo-root entry are documented;
  - `convert` resolves paths consistently;
  - version numbers are no longer pinned in the text;
  - a single execution order is added.
- **Afterwards:** custom tab completion was dropped (your decision), because wt's own completion and picker, plus
  zoxide and fzf, already cover it.
- **Third review:** 9 findings, all applied:
  - this session sets PATH explicitly, because its shell is a frozen copy;
  - the tests use their own throwaway bin directory;
  - `z z main`;
  - apt is removed as a Worktrunk install option;
  - `-h`/`--help` and usage text are specified;
  - the `post-remove` check uses `--foreground` or the log;
  - the interactive checks are marked as yours;
  - the extra Claude Code state keyed by path is noted;
  - the verification uses `mktemp -d`.
- **Afterwards:** the dispatcher became `git bare-worktree` with the alias `git bwt`, and the docs were split into
  a short README plus `bare-worktree/docs/` (getting started, usage, architecture, decisions, gotchas). Both were
  your decisions. The preflight's Setup link now points at `docs/getting-started.md#setting-up-worktrunk`.
- **Afterwards:** a redacted copy of this plan plus a decisions-and-divergences file go in
  `bare-worktree/docs/plans/` (your decision). They stay in the repo and aren't shipped.

What's left are known limits and checks, not defects:
- **No git subcommand can change the shell's directory**, and `git switch-worktree` inherits that. It is documented.
- **During implementation:**
  - the exact message wt prints when shell integration isn't active;
  - the `post-remove` behaviour of `zoxide remove`;
  - `FZF_CTRL_R_COMMAND` (only relevant if you later turn on fzf's key bindings).
- **Before converting lean-ctx:** check for lean-ctx per-project data keyed by the root path (none was found).

Naming stays `*-worktree`, with `git bare-worktree` as the dispatcher and `git bwt` as its short alias (your
decision, replacing the earlier `git bare`).

## Verification

- `mise run lint` in git-toolbelt.
- `umask 077; PATH=$PWD:$PWD/portmanteaus:$PWD/bare-worktree:$PATH scripts/test-bare-worktree.sh`, then again with
  `TOOLBELT_TEST_REAL_WT=1`.
- `mise run smoke` checks the `bin/` and `share/` layout, including `share/…/bare-worktree/docs/`, with no
  `plans/` folder in it.
- The redaction grep on `bare-worktree/docs/plans/*.md` finds nothing, and the plan copy has its Created, Approved
  and Implemented dates.
- The docs link check (in the test script) passes: every absolute link into `bare-worktree/` resolves to a file and
  heading in the working tree.
- Manual zoxide check, in a scratch folder `t=$(mktemp -d)` with `_ZO_DATA_DIR=$t/zo` so the real zoxide history
  is untouched: with `zoxide init bash` loaded, `git init-worktree $t/z` then `z z main` lands in `$t/z/main`.
  (zoxide's last word has to match the last folder, so `z z` alone wouldn't.)
  With the hook block enabled, `wt switch -c tmp/zx --no-cd` then `z zx` works, and `wt remove` deletes the zoxide
  entry (checked with `zoxide query -l`, since the hook runs in the background). Then `rm -rf "$t"`.
- Install-shape check: extract the built tarball and put only `<extract>/bin` on PATH in a clean shell, the way mise
  does. Then confirm `git bare-worktree config-example`, `git init-worktree "$t/a"` (in a fresh `mktemp -d`), and the
  printed `Next:` line.
- Local setup steps on the author's machine; not part of the design.
- No release is triggered. 2.1.0 ships when you merge release-please's PR.
