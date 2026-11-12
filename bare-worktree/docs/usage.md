# Usage

Back to the [bare-worktree README](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/README.md).

Day-to-day reference. For first-time setup, see
[Getting started](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/getting-started.md).

## Commands reference

### Which form to use

The same commands can be called three ways:

| Verb | Dispatcher | Short alias |
|---|---|---|
| `git clone-worktree` | `git bare-worktree clone` | `git bwt clone` |
| `git init-worktree` | `git bare-worktree init` | `git bwt init` |
| `git convert-worktree` | `git bare-worktree convert` | `git bwt convert` |
| `git switch-worktree` | `git bare-worktree switch` | `git bwt switch` |

They behave the same. Use the `*-worktree` verbs if you think in git verbs. Use `git bwt <action>` if you
want one short entry point to remember.

### Help: use -h

Every command prints its usage with `-h` and exits 0, even when `wt` is not installed. That includes
`git bare-worktree <action> -h` and `git bwt <action> -h`, which print the verb's usage.

`--help` does not work for any of them, including `git bare-worktree --help` and `git bwt --help`. git
turns `git <verb> --help` into `git help <verb>`, which looks for a man page and prints
`No manual entry for git-<verb>`. Use `-h`; it works for every command.

`git switch-worktree -h` (and `git bwt switch -h`) shows `wt switch`'s help, because that command passes
everything to `wt switch`. It is the one help that needs `wt`.

### Repository variables

`git clone-worktree` and `git init-worktree` ignore `GIT_DIR`, `GIT_WORK_TREE` and the other variables that
point git at a repository, so a variable left exported in your shell, or `git --git-dir=... init-worktree`,
cannot make them write into another repo.

`git convert-worktree` always converts the repo you name, or the one you are in; `GIT_DIR` alone never
selects it. If `GIT_DIR` or `GIT_WORK_TREE` is set, it must name that same repo, or convert refuses (see
[git convert-worktree](#git-convert-worktree)). So `git --git-dir=<repo>/.git convert-worktree <repo>`
converts `<repo>`, but `GIT_DIR=<repo>/.git git convert-worktree` run from outside `<repo>` refuses with
`git convert-worktree: '.' is not inside a git repository` (or, from inside another repo, with the
`GIT_DIR` refusal). Pass `<repo>`, or run it inside the repo.

### Preflight

Every command except `git bare-worktree config-example` checks that `wt` is on `PATH` before it touches
anything. Only `-h` and bad usage are handled first. If `wt` is missing, the command changes nothing, prints
this to stderr and exits 1:

```
git <verb>: Worktrunk (wt) is required but was not found on PATH.
  Install: https://github.com/max-sixty/worktrunk#install
  Setup:   https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/getting-started.md#setting-up-worktrunk
```

### Messages and exit codes

- Refusals look like `git <verb>: <reason>`. They exit 1 and change nothing.
- Warnings look like `git <verb>: warning: <text>`. The command still exits 0.
- Bad usage prints the usage line to stderr and exits 2.
- When a git step fails, git's own message is shown and the command exits with a non-zero status.

| Exit | Meaning |
|---|---|
| 0 | Done. Warnings may have been printed. |
| 1 | Refused, or `wt` is missing. Nothing was changed. |
| 2 | Bad usage. Nothing was changed. |
| other | A git step failed. Read git's message above it. |

Warnings that clone, init and convert can print (each still exits 0):

```
git <verb>: warning: 'wt switch' failed (exit <n>); the checkout is ready, but Worktrunk did not confirm it
git <verb>: warning: 'zoxide add' failed (exit <n>); the checkout is ready, but zoxide does not know it yet
```

`git convert-worktree` has two more; see [git convert-worktree](#git-convert-worktree).

### git clone-worktree

```
usage: git clone-worktree <repository> [directory]
```

Clones `<repository>` as a bare repo into `<directory>/.git`, sets the normal `origin/*` fetch refspec,
fetches, and creates a worktree for the remote's default branch at `<directory>/<branch-dir>`. The default
branch tracks its `origin` branch. `<directory>` defaults to the repository name, worked out the way
`git clone` does it: `.../repo/.git`, `.../repo.git` and `host:path/repo.git` all give `repo`. HTTPS and SSH
URLs work, with or without the `.git` suffix.

```console
$ git clone-worktree https://github.com/sdthach/git-toolbelt
$ git clone-worktree git@github.com:sdthach/git-toolbelt.git toolbelt
```

Refusals and failures:

| When | Message | Exit |
|---|---|---|
| No repository, or an option as the first argument, or more than two arguments | the usage line | 2 |
| `wt` is missing | the [preflight](#preflight) message | 1 |
| The directory is empty, `.`, `..` or starts with `-` | `git clone-worktree: invalid destination '<directory>'` | 2 |
| The directory already exists, even if empty | `git clone-worktree: destination '<directory>' already exists` | 1 |
| The clone, fetch or checkout fails | git's message, then `git clone-worktree: removed the partial clone at <directory>` | git's |

Missing parent folders are created, as `git clone` does, so `git clone-worktree <repository> deep/a/b`
works. When a git step fails, clone removes `<directory>` (shown as an absolute path), so you can retry
straight away. Parent folders it created stay.

### git init-worktree

```
usage: git init-worktree <directory> [--branch <name>]
```

Starts a new repo: a bare `<directory>/.git`, a worktree at `<directory>/<branch-dir>`, and one empty root
commit, so `wt switch -c` has something to branch from. The branch is `--branch`, else your
`init.defaultBranch`, else `main`. It is set explicitly because plain `git init` falls back to `master`.

```console
$ git init-worktree my-project
$ git init-worktree my-project --branch trunk
```

Refusals and failures:

| When | Message | Exit |
|---|---|---|
| No directory, two directories, `--branch` without a name, or unknown options | the usage line | 2 |
| `wt` is missing | the [preflight](#preflight) message | 1 |
| The directory already exists, even if empty | `git init-worktree: '<directory>' already exists` | 1 |
| git is older than 2.42 | `git init-worktree: git 2.42 or later is required for 'git worktree add --orphan' (found <version>)` | 1 |
| The branch name is not valid | `git init-worktree: '<name>' is not a valid branch name` | 1 |
| `user.name` or `user.email` is not set | `git init-worktree: set user.name and user.email first; nothing was created` | 1 |
| A git step fails (for example, commit signing) | git's message, then `git init-worktree: removed the partial repository at <directory>` | git's |

Like clone, init creates missing parent folders, and on failure removes only `<directory>`; parent folders
it created stay.

The root commit is made with `--no-verify`, so your commit hooks do not run for it. `commit.gpgSign` still
applies: with signing on, the root commit is signed, and if signing fails the new repository is removed.

To publish the repo later, see [Start a new repo](#start-a-new-repo).

### git convert-worktree

```
usage: git convert-worktree [path] [--dry-run]
```

Converts an existing normal clone into the layout, in place. `path` defaults to the current directory. A
subfolder works: the command finds the top level with `git rev-parse --show-toplevel`. After it runs,
`<repo>/.git` is bare and your files, including uncommitted, staged, untracked and ignored ones, are in
`<repo>/<branch-dir>`.

```console
$ git convert-worktree --dry-run ~/repos/my-clone
$ git convert-worktree ~/repos/my-clone
```

`--dry-run` runs every check, prints the plan and exits without changing anything.

It refuses, and changes nothing, when:

| When | Message | Exit |
|---|---|---|
| The path is not a directory | `git convert-worktree: '<path>' is not a directory` | 1 |
| The path is not in a git repository | `git convert-worktree: '<path>' is not inside a git repository` | 1 |
| The repo is already bare | `git convert-worktree: '<path>' is already a bare repository; there is nothing to convert` | 1 |
| The path is not in a working tree | `git convert-worktree: '<path>' is not inside a working tree` | 1 |
| The path is a linked worktree, not the main one | `git convert-worktree: '<top>' is a linked worktree; convert the repository's main worktree instead (<main>)` | 1 |
| The git dir is not `<top>/.git` | `git convert-worktree: the git directory is not '<top>/.git' (a separate git dir or core.worktree); only the standard layout can be converted` | 1 |
| `GIT_DIR` names another repository | `git convert-worktree: GIT_DIR (<value>) is not the git directory of '<top>'; unset it, or pass the matching path` | 1 |
| `GIT_WORK_TREE` names another folder | `git convert-worktree: GIT_WORK_TREE (<value>) is not '<top>'; unset it, or pass the matching path` | 1 |
| The repo is your home directory or `/` | `git convert-worktree: '<top>' is your home directory or /; moving everything in it is not supported` | 1 |
| HEAD is detached | `git convert-worktree: HEAD is detached; check out a branch first (git switch <branch>)` | 1 |
| HEAD is not a local branch | `git convert-worktree: HEAD points at '<ref>', not a local branch` | 1 |
| The branch has no commits yet | `git convert-worktree: branch '<branch>' has no commits yet; make a first commit, then convert` | 1 |
| A merge, rebase, cherry-pick, revert or bisect is in progress | `git convert-worktree: a <operation> is in progress; finish or abort it first` | 1 |
| Submodules are initialised (`.git/modules` exists) | `git convert-worktree: submodules are initialised ('<gitdir>/modules' exists); converting them is not supported` | 1 |
| Sparse checkout is on | `git convert-worktree: sparse checkout is on; run 'git sparse-checkout disable' first` | 1 |
| Another git process holds the index lock | `git convert-worktree: '<gitdir>/index.lock' exists: another git process is running, or one crashed (then remove the file)` | 1 |
| A linked worktree is already registered at the target folder | `git convert-worktree: a linked worktree is already registered at '<checkout>'` | 1 |
| The stage folder already exists | `git convert-worktree: '<stage>' already exists` | 1 |
| The repo folder is not writable | `git convert-worktree: '<top>' is not writable` | 1 |
| A top-level folder is not writable, so it cannot be moved | `git convert-worktree: '<entry>' is not writable, so it can't be moved; make it writable (chmod u+w) and retry` | 1 |
| Unknown options or more than one path | the usage line | 2 |

`--dry-run` output starts with `Dry run: nothing was changed.`, then the repository, branch and worktree
paths and the nine steps, filled in for your repo.

Linked worktrees that sat inside the old working tree (for example `.claude/worktrees/*`) are repaired with
`git worktree repair`. Linked worktrees outside the repo need nothing. If `origin` exists and
`remote.origin.fetch` is not set, the command sets the standard refspec. A custom refspec is left alone.

These only warn, because every file is already in place:

```
git convert-worktree: warning: 'git worktree repair' failed; rerun it: git -C <checkout> worktree repair <moved worktree paths>
git convert-worktree: warning: 'git remote set-head origin --auto' failed (offline?); run it later
```

The repair warning prints the full command, with each moved worktree's new path.

Steps 2 to 7 only rename files and write a few small files. During them, the command ignores Ctrl-C and
other hang-up, interrupt and terminate signals, so it cannot be stopped halfway by accident. The git calls
in those steps run without git hooks (`-c core.hooksPath=/dev/null` for `git worktree add`) and without
fsmonitor (`-c core.fsmonitor=false` for `read-tree` and `ls-files`), so none of your own programs runs
while signals are ignored. If a step from 2 to 6 fails anyway, the command stops, rolls nothing back, and prints where your files are and the exact
commands to put them back, in order:

```
git convert-worktree: stopped at step <n>; nothing was rolled back.
  Your files are in <stage>.
  To restore the original clone, run these commands in order:

    cd -- <repo>
    ...
```

The second line depends on the step: at step 2 it reads
`Some of your files are in <stage>, the rest are still in <repo>.`, and at step 6
`Your files are in <stage> and partly in <checkout>.` The commands remove only the worktree record this
run created (`rm -rf -- .git/worktrees/<name>`). They never run `git worktree prune`, which would also
delete the records of worktrees that are only out of reach for the moment.

Steps 4 and 5 also stop, with the same recovery, when a safety check fails:

```
git convert-worktree: expected one new entry in <gitdir>/worktrees, found: <entries>
git convert-worktree: the new worktree's git dir is <path>, not <gitdir>/worktrees/<name>
git convert-worktree: the new worktree can't read the copied index
```

The old index is removed only after the new worktree has read its copy. A split index (`sharedindex.*`
files) is copied along with it.

If a step from 7 on fails, every file is already in the new worktree, and it prints the one follow-up you
need instead of restore commands:

```
git convert-worktree: stopped at step <n>, after every file was in place in <checkout>.
  Repair the linked worktrees that moved with the files:
    git -C <checkout> worktree repair <moved worktree paths>
```

(at step 7, when worktrees were nested in the repo), or at step 8:

```
git convert-worktree: stopped at step 8, after every file was in place in <checkout>.
  Finish the remote setup:
    git -C <checkout> config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
    git -C <checkout> remote set-head origin --auto
```

The `config remote.origin.fetch` line appears only when the refspec should have been set and was not yet
written; the `set-head` line only when `origin` has a URL.

On success, before the [output](#output) lines, it prints:

```
Converted <repo>: .git is now a bare repository, and <branch> is checked out in <checkout>.
```

When the repo has linked worktrees outside its folder, it adds a line suggesting `wt step relocate`, which
can move them into the layout. Worktrees that were nested in the repo are not counted; they moved with the
files.

```
Hint:     <n> linked worktree(s) outside the repo may not match the layout; preview moving them with: wt -C <checkout> step relocate --dry-run
```

### git switch-worktree

```console
$ git switch-worktree -c feat/x     # create branch and worktree
$ git switch-worktree ^             # the default branch's worktree
$ git switch-worktree               # wt's picker
```

After the preflight, it runs `wt switch` with your arguments. The arguments, output and exit code are all
wt's. It does not change your directory; see [Getting into a worktree](#getting-into-a-worktree).

Use it to create or prepare worktrees from git muscle memory, or in scripts. To move into a worktree, use
`wt switch` (with shell integration) or `cd`.

### git bare-worktree

```
usage: git bare-worktree <clone|convert|init|switch> [args...]
       git bare-worktree config-example [--project]
```

`clone`, `convert`, `init` and `switch` run `git-clone-worktree`, `git-convert-worktree`,
`git-init-worktree` and `git-switch-worktree` with the remaining arguments, after the
[preflight](#preflight). `git bare-worktree <action> -h` skips the preflight and shows the verb's usage.

| When | Message | Exit |
|---|---|---|
| No action, or `config-example` with anything but `--project` | the usage | 2 |
| An unknown action | `git bare-worktree: unknown action '<action>'`, then the usage | 2 |
| `wt` is missing | the [preflight](#preflight) message, with `git bare-worktree` as the prefix | 1 |
| The verb script is not on `PATH` | `git bare-worktree: git-<action>-worktree was not found on PATH; install all six bare-worktree commands together` | 1 |

`config-example` prints the sample user config (`config.toml.example`). `config-example --project` prints
the sample project config (`wt.toml.example`). Neither needs `wt`. See [Config](#config).

### git bwt

`git bwt` is `git bare-worktree` under a shorter name. Arguments, usage text and exit codes are the same,
and the usage text always shows `git bare-worktree`.

### Output

Clone, init and convert end with a blank line and these two lines:

```

Checkout: <checkout>
Next:     cd <checkout>   # or: wt -C <container> switch <branch>
```

When zoxide is on `PATH`, the `Next:` line ends with a zoxide jump as well:

```
Next:     cd <checkout>   # or: wt -C <container> switch <branch>   |   z <container-name> <branch-dir>
```

For example, after `git clone-worktree https://github.com/sdthach/git-toolbelt` in `/work`:

```

Checkout: /work/git-toolbelt/main
Next:     cd /work/git-toolbelt/main   # or: wt -C /work/git-toolbelt switch main   |   z git-toolbelt main
```

`Checkout:` shows the absolute path as it is. On the `Next:` line, a word is put in single quotes when it
contains anything other than letters, digits and `_ . / : @ % + = , -`, so the line can be pasted into a
shell. Both `z` words are needed; see [Moving around](#moving-around).

Before those lines, the commands run `wt -C <container> switch <branch> --no-cd --no-hooks`, which prints
Worktrunk's own line about the worktree. If that call fails, you get a warning (see
[Messages and exit codes](#messages-and-exit-codes)) and the command still exits 0, because the git work is
already done. When zoxide is on `PATH`, they also run `zoxide add <checkout>`; its failure is only a warning
too.

## Getting into a worktree

None of these commands change your shell's directory. A git subcommand runs in a child process, and a child
process cannot change its parent shell's directory. `git clone` works the same way.

To get into a worktree:

- `cd <path>`, using the `Checkout:` path; or
- `wt switch <branch>`, which changes directory through Worktrunk's shell integration.

`git switch-worktree` does not change directory either. It runs wt as a program, not through wt's shell
function, so wt creates or finds the worktree and then says, on stderr, that it could not move you there.
The exit status is still 0. With wt 0.81.0, through `git switch-worktree <branch>`:

```
▲ Worktree for <branch> @ <path>, but cannot change directory — ran git wt; running through git prevents cd
↳ For automatic cd, invoke directly (with the -): git-wt
```

That hint is misleading here. wt assumes it was started as `git wt`, but there is no `git-wt` command on
Linux or macOS; only Worktrunk's Winget package installs one, on Windows. Use `wt switch <branch>` or `cd`
instead. See [the decision](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-wt-messages-without-shell-integration).

wt prints the same kind of message when you run `wt switch` itself without working shell integration. If
the integration is installed but not active in this shell (for example, you have not restarted it):

```
▲ Worktree for <branch> @ '<path>', but cannot change directory — ran <wt binary>; shell integration wraps wt
↳ To change directory, run wt switch <branch>
```

If it is not installed:

```
▲ Worktree for <branch> @ <path>, but cannot change directory — shell integration not installed
↳ To enable automatic cd, run wt config shell install
```

For either, see
[Setting up Worktrunk](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/getting-started.md#setting-up-worktrunk).

## Moving around

- `z <repo> <branch-dir>` jumps with zoxide, for example `z git-toolbelt main`. The last word must match the
  last part of the path, so `z git-toolbelt` alone does not find `git-toolbelt/main`. Every repo has a
  `main`, so `z main` alone is ambiguous.
- `zi` opens a fzf list of the folders zoxide knows.
- `wt switch` with no arguments opens Worktrunk's picker. Add `--branches` to include branches without a
  worktree, or `--remotes` for remote branches.

zoxide learns a folder when you `cd` into it. With the `post-start` hook from
[Getting started](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/getting-started.md#optional-zoxide-and-fzf),
it also learns every new worktree when wt creates it.

### Tab completion

No custom completion is shipped. git's bash completion already completes the command names
(`git switch-w<TAB>`, `git bare-w<TAB>`, `git bw<TAB>`), and paths complete as file names. For branch names,
use `wt switch <TAB>` (wt's own completion), wt's picker, or `z` and `zi`.

## Daily workflow

```console
$ wt switch -c feat/auth            # new branch and worktree, and cd into it
$ git switch-worktree -c feat/auth  # same, but stays in the current folder
$ wt switch ^                       # back to the default branch's worktree
$ wt switch -                       # the previous worktree
$ wt list                           # all worktrees and their status
$ wt remove                         # remove this worktree; delete the branch if merged
$ wt step prune --dry-run           # worktrees and branches already merged
$ wt step relocate --dry-run        # worktrees that are not where the layout puts them
```

After `wt switch -c feat/auth`, you are in the new folder, so zoxide learns it. After
`git switch-worktree -c feat/auth`, `z auth` works only if the `post-start` hook is on, because you never
visited the folder. Otherwise use `zi` or `wt switch`.

`wt step prune` and `wt step relocate` change things; run them with `--dry-run` first.

## Manual recipes

The same results using only `git` and `wt`. Run the lines in order.

### Clone a remote

```sh
git clone --bare https://github.com/sdthach/git-toolbelt git-toolbelt/.git
cd git-toolbelt
git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git fetch origin
git remote set-head origin --auto
git branch --set-upstream-to=origin/main main
git worktree add main main
wt switch main --no-cd --no-hooks
cd main
```

`git clone --bare` does not set a fetch refspec, so without the `config` line `git fetch` would not update
`origin/*`. Replace `main` with the remote's default branch if it differs (`git symbolic-ref
refs/remotes/origin/HEAD` shows it). For a branch name with `/`, use `-` in the folder name:
`git worktree add feature-x feature/x`.

### Start a new repo

```sh
git init --bare -b main my-project/.git
cd my-project
git worktree add --orphan -b main main
cd main
git commit --allow-empty -m "Initial commit"
```

Later, to publish it:

```sh
git remote add origin git@github.com:owner/my-project.git
git push -u origin main
```

In a bare repo, `git remote add` sets the normal fetch refspec, so nothing else is needed.

### Convert an existing clone

This is what `git convert-worktree` does, using lean-ctx in `~/repos/lean-ctx` as the example. Check first
that you are on a branch and nothing is in progress (`git status`), and close editors and agents that use
the folder. These steps assume `git config extensions.worktreeConfig` prints nothing or `false`; if it
prints `true`, use `git convert-worktree`, which handles that case.

```sh
cd ~/repos/lean-ctx
git worktree list --porcelain        # note any linked worktrees inside the repo

# 1. Move everything except .git into a stage folder inside the repo.
stage=.convert-worktree.manual
mkdir "$stage"
for f in * .[!.]* ..?*; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  case $f in .git | "$stage") continue ;; esac
  mv -- "$f" "$stage/"
done

# 2. Make .git bare and add a worktree for the branch, without checking files out.
git config core.bare true
git config --unset core.worktree || true
git worktree add --no-checkout main main

# 3. Give the new worktree the old index and HEAD reflog.
gitdir=$(git -C main rev-parse --absolute-git-dir)
for f in .git/sharedindex.*; do [ -f "$f" ] && cp -p "$f" "$gitdir/"; done   # split index only
cp .git/index "$gitdir/index"
git -C main ls-files --stage > /dev/null     # the new worktree must read its index
mkdir -p "$gitdir/logs" && cp .git/logs/HEAD "$gitdir/logs/HEAD"
if [ -f .git/config.worktree ]; then mv .git/config.worktree "$gitdir/"; fi
rm .git/index

# 4. Move the files into the worktree.
for f in "$stage"/* "$stage"/.[!.]* "$stage"/..?*; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  mv -- "$f" main/
done
rmdir "$stage"

# 5. Repair linked worktrees that were inside the old working tree (one path per worktree).
git worktree repair main/.claude/worktrees/<name>

# 6. Make sure origin/* is fetched, and record the remote's default branch.
git config --get remote.origin.fetch ||
  git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git remote set-head origin --auto

# 7. Let Worktrunk see the worktree, then check.
wt switch main --no-cd --no-hooks
git -C main status
```

Replace `main` with your branch name (with `/` turned into `-` for the folder). Every move stays inside the
repo folder, so it is a rename on the same filesystem: even a large `rust/target` moves instantly. Staging
first avoids a clash when the repo tracks a top-level folder with the branch's name. `git -C main status`
should show the same changes as before. `git worktree repair` prints `repair: gitdir incorrect: ...` when it
fixes a worktree; that is expected.

Now read [Gotchas](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/gotchas.md#absolute-paths-change-after-convert):
the repo's files now live one folder deeper.

#### Undo a conversion

First remove any worktrees you created in the layout (`wt remove <branch>`); otherwise they end up as
folders inside the restored working tree. If you switched branches inside `main/`, switch back first.

```sh
cd ~/repos/lean-ctx
gitdir=.git/worktrees/main
for f in "$gitdir"/sharedindex.*; do [ -f "$f" ] && cp -p "$f" .git/; done   # split index only
cp "$gitdir/index" .git/index
if [ -f "$gitdir/config.worktree" ]; then mv "$gitdir/config.worktree" .git/; fi

stage=.undo-worktree.manual
mkdir "$stage"
for f in main/* main/.[!.]* main/..?*; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  case $f in main/.git) continue ;; esac
  mv -- "$f" "$stage/"
done
rm main/.git && rmdir main && rm -rf "$gitdir"
git config core.bare false
for f in "$stage"/* "$stage"/.[!.]* "$stage"/..?*; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  mv -- "$f" .
done
rmdir "$stage"

git worktree repair .claude/worktrees/<name>
git status
```

Do not run `git worktree prune`, before or after the repair. While the nested worktrees' recorded paths
still point into `main/`, prune deletes their records, and it also deletes the record of any outside
worktree that is out of reach at that moment (for example, on an unmounted drive), with its staged changes.
Remove only the record you created, as above.

## Config

Worktrunk reads two files. [Architecture](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/architecture.md#how-worktrunk-config-combines)
explains how they combine.

- **User config** (`~/.config/worktrunk/config.toml`, personal). `git bare-worktree config-example` prints a
  sample. Override settings for one repo with a table:

  ```toml
  [projects."github.com/owner/repo"]
  worktree-path = "{{ repo_path }}/../{{ branch | sanitize }}"
  ```

  Keys may use `*`, for example `[projects."github.com/owner/*"]`.

- **Project config** (`.config/wt.toml` in the repo, committed). Create one in the current worktree with
  `wt config create --project`, or start from `git bare-worktree config-example --project`. It holds hooks
  such as `pre-start = "mise trust"`, `[list] url`, and copy-ignored excludes. It never holds
  `worktree-path`; the layout is each person's choice.

`wt config show` shows which files wt found and what they contain.

The sample files are also installed with the package; see
[Architecture](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/architecture.md#packaging).

## Standalone install

To use only these commands, without the rest of git-toolbelt, copy all six scripts together from a checkout
of this repo:

```sh
install -m 755 bare-worktree/git-* ~/.local/bin/
```

Install all six: `git-bare-worktree` runs the four verb scripts from `PATH`, and `git-bwt` runs
`git-bare-worktree`.

If you once installed `wt-clone` by hand (an earlier, unreleased version of `git clone-worktree`), remove
it:

```sh
rm ~/.local/bin/wt-clone
```
