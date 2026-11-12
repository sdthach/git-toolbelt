# bare-worktree

Git commands that set up and use the Worktrunk "bare" layout. In this layout `<repo>/.git` is a bare
repository, and every branch you work on is a sibling worktree next to it:

```
repo/
├── .git/        # bare repository: objects, refs, config
├── main/        # worktree for branch main
└── feat-x/      # worktree for branch feat/x
```

Why use it:

- **Parallel branches and agents.** Each branch has its own folder, so two editors, test runs or coding
  agents can work on different branches at the same time.
- **No stash juggling.** Switching branches means changing folders. Uncommitted work stays where it is.
- **One shared object store.** All worktrees use the same `.git`, so a fetch in one is visible in all, and
  nothing is cloned twice.

The commands need [Worktrunk](https://github.com/max-sixty/worktrunk) (`wt`) on `PATH`. They stop with a
clear message if it is missing.

## Commands

| Command | What it does |
|---|---|
| `git clone-worktree <repository> [directory]` | Clone a remote into the layout and check out its default branch |
| `git init-worktree <directory> [--branch <name>]` | Start a new, empty repo in the layout |
| `git convert-worktree [path] [--dry-run]` | Convert an existing normal clone in place |
| `git switch-worktree [wt switch args...]` | Pass everything to `wt switch` |
| `git bare-worktree <clone\|convert\|init\|switch> [args...]` | Run one of the four commands above; `git bare-worktree config-example [--project]` prints a sample Worktrunk config |
| `git bwt ...` | Short alias for `git bare-worktree` |

None of them change your shell's directory, just like `git clone`. Each one prints the checkout path and
the command to get there.

## Quick start

```console
$ mise use -g github:sdthach/git-toolbelt worktrunk fzf zoxide
$ wt config shell install              # then restart the shell
$ git bare-worktree config-example     # copy its worktree-path line into your wt config
$ git clone-worktree https://github.com/sdthach/git-toolbelt
$ cd git-toolbelt/main
```

## Docs

- [Getting started](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/getting-started.md):
  install, set up Worktrunk, and create your first repo.
- [Usage](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/usage.md): every command and
  message, daily workflow, and manual recipes with plain `git` and `wt`.
- [Architecture](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/architecture.md): the
  layout on disk, how Worktrunk config combines, and what each command does step by step.
- [Decisions](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/decisions.md): why it works
  this way, and what was given up.
- [Gotchas](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/gotchas.md): things that
  surprise people.

The original design and every later change are kept in
[docs/plans/](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-plan.md)
(in the repository only, not in packages).
