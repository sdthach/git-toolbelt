# Gotchas

Back to the [bare-worktree README](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/README.md).

Things that surprise people.

## Absolute paths change after convert

After `git convert-worktree`, the files of `~/repos/project` live in `~/repos/project/main`. Anything that
remembers the old path needs attention:

- **IDE projects** still point at the container. Reopen the project from `main/`.
- **Build caches** keyed by absolute path rebuild. For example, cargo rebuilds `target/` once.
- **Claude Code** keys its memory, its folder trust prompt and its `--resume` history by path. In `main/`
  you get the trust prompt again, old sessions do not show in `--resume`, and project memory starts empty.
  Copy the memory folder under `~/.claude/projects/` from the old path's entry to the new one if you want
  to keep it.
- **Running editors, agents and daemons** whose working directory was the old root keep running against a
  folder that is now the bare container. Close them before you convert, and restart them in `main/`.
- **zoxide** still has its entry for the old root, which now points at the bare container. Use
  `z <repo> main`. See [zoxide needs two words](#zoxide-needs-two-words).

Paths stored inside the tree break too, because every file moved one folder deeper:

- **A Python `.venv`** has the old absolute path in its scripts' shebang lines and in its config, so
  `pip`, `pytest` and the other entry points stop working. Delete it and create it again in `main/`.
- **Absolute git settings** such as `core.hooksPath` or `commit.template` that point into the repo still
  name the old path. Check them with `git -C main config --show-origin --get-regexp '^(core\.hookspath|commit\.template)$'`
  and update them, or make them relative.
- **Relative symlinks that leave the repo** with `../` now resolve one folder too shallow: a link
  `../shared` that pointed next to the repo now points inside the container. Links that stay inside the
  repo are fine.

## Some refs stay with the container

After convert, the bare `.git` keeps the state that git stores per repository: `ORIG_HEAD`, `FETCH_HEAD`
and any `refs/worktree/*` refs. The new `main/` worktree has its own, empty, set, so `git reset ORIG_HEAD`
or `git merge FETCH_HEAD` in `main/` does not see the values from before the conversion. Branches, tags,
remote-tracking refs and the HEAD reflog carry over. `git stash` survives too: stashes are shared by all
worktrees.

## zoxide needs two words

zoxide's last search word must match the last part of the path. `z project` matches `~/repos/project`, which
is now the bare container, not `~/repos/project/main`. Use `z project main`. `z main` alone is ambiguous,
because every repo has a `main`.

## Submodules are not supported by convert

`git convert-worktree` refuses when `.git/modules` exists, which is the case once any submodule has been
initialised. `git submodule deinit` does not remove `.git/modules`, so it does not help. Keep such a repo
as a normal clone.

## feature/x and feature-x share a folder

Folder names replace `/` with `-`, so the branches `feature/x` and `feature-x` both map to `feature-x/`. wt
refuses the second one. Pick a different folder with `wt switch --path <dir>`, or rename one branch.

## Hooks do not run on the first checkout

Clone, init and convert run `wt switch --no-hooks`, so neither your `post-start` hooks nor the project's
hooks run for the first checkout. Run them by hand once you have read the project's `.config/wt.toml`:

```console
$ wt hook post-start --foreground
```

The commands do run `zoxide add` themselves, so the first checkout is still known to zoxide.

`git init-worktree` also makes its empty root commit with `--no-verify`, so your `pre-commit` and
`commit-msg` hooks do not run for it. Commit signing (`commit.gpgSign`) still applies.

`git convert-worktree` runs no git hooks and no fsmonitor while it moves your files (steps 2 to 7), because
it ignores Ctrl-C during those steps and anything it started would ignore it too.

## GIT_DIR does not pick the repo for convert

`GIT_DIR=<repo>/.git git convert-worktree` run from outside the repo does not convert `<repo>`. It refuses
with `git convert-worktree: '.' is not inside a git repository`, because convert works on the path you
give it, or the current directory. Inside another repo it refuses with the `GIT_DIR (...) is not the git
directory of ...` message instead. Run `git convert-worktree <repo>`, or `cd` into the repo first.

## git verb --help says No manual entry

`git clone-worktree --help` prints `No manual entry for git-clone-worktree`. git turns `--help` into
`git help <verb>`, which looks for a man page. The same happens to `git bare-worktree --help` and
`git bwt --help`. Use `-h`; it works for every command.

## git switch-worktree does not cd

It runs wt as a program, so wt cannot change your shell's directory. Use `wt switch <branch>` (with shell
integration) or `cd`.

wt's message about it is misleading here:

```
↳ For automatic cd, invoke directly (with the -): git-wt
```

wt thinks it was started as `git wt`. There is no `git-wt` command on Linux or macOS; only Worktrunk's
Winget package installs one, on Windows. Ignore the hint. The full messages are in
[Usage](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/usage.md#getting-into-a-worktree).

## post-* hooks fail silently

wt runs `post-*` hooks (`post-start`, `post-remove`, ...) in the background and writes their output to a log.
A failing hook never shows in the terminal. To see what happened:

```console
$ wt config state logs get               # list the log files
$ wt hook post-start --foreground        # run the hook inline, output in the terminal
```

## Works with atuin

atuin binds Ctrl-R and the Up arrow, and installs its own copy of bash-preexec, which wraps
`PROMPT_COMMAND`.

- **fzf's key bindings take Ctrl-R.** `eval "$(fzf --bash)"` binds Ctrl-R, Ctrl-T and Alt-C. Whichever of
  fzf and atuin loads last owns Ctrl-R. That is why these docs leave fzf's key bindings off: `zi` only needs
  the fzf program.
- **zoxide goes last.** `eval "$(zoxide init bash)"` adds its hook to `PROMPT_COMMAND`. Put it on the last
  line of `~/.bashrc`, after atuin, Worktrunk and your prompt (for example starship), so nothing later
  resets `PROMPT_COMMAND`. If zoxide prints `zoxide: detected a possible configuration issue.`, its hook is
  missing from `PROMPT_COMMAND`; fix the order rather than silencing the message.
- **Worktrunk's shell function** uses `builtin cd` and does not touch key bindings or `PROMPT_COMMAND`.

If you want fzf's Ctrl-T and Alt-C as well, either:

- load `eval "$(fzf --bash)"` before `eval "$(atuin init bash)"`, so atuin's Ctrl-R is bound last and wins
  (mise must then be activated before both, so fzf is on `PATH`); or
- set `FZF_CTRL_R_COMMAND=` (empty) before `eval "$(fzf --bash)"`. fzf then skips its Ctrl-R binding and
  keeps Ctrl-T and Alt-C. Checked against fzf 0.75.

Check in a new terminal afterwards: Ctrl-R and the Up arrow still open atuin, and
`echo "$PROMPT_COMMAND"` contains `__zoxide_hook`.
