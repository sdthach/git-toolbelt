# Portmanteau shortcuts

Back to the [README](../README.md).

`portmanteaus/` holds a set of short, single-word `g`+verb executables — everyday Git operations without the `git ` prefix or without typing the full subcommand name. They live alongside the `git-*` scripts on `PATH` (installed by the same Homebrew formula, or picked up via `.envrc` during in-repo dev) but are standalone commands, not `git <verb>` subcommands — so you run `gadd` (not `git gadd`).

## Thin vs. smart

Most of these are **thin**: a one-line `exec git <verb> "$@"` that just forwards straight to the underlying Git command (or its shell built-in), with full flag passthrough. A few are **smart**: they delegate to one of this toolbelt's own `git-*` scripts instead of the raw Git command, because that script already does something more useful than the default. Those are marked below.

## Reference

| Command | Behavior | | Command | Behavior |
|---|---|---|---|---|
| `getch` | `exec git fetch "$@"` | | `glog` | `exec git log "$@"` |
| `gull` | `exec git pull "$@"` | | `granch` | `exec git branch "$@"` |
| `gulp` | fetches, then `exec git pull "$@"`; aborts if the fetch fails | | `gtash` | `exec git stash "$@"` |
| `gush` | `exec git push-current "$@"` — **smart**, delegates to [`git-push-current`](commands.md#git-push-current) | | `gadd` | `exec git add "$@"` |
| `gommit` | `exec git commit "$@"` | | `gmend` | `exec git commit --amend "$@"` |
| `gtatus` | `exec git status "$@"` | | `giff` | `exec git diff "$@"` |
| `gout` | `exec git workon "$@"` — **smart**, delegates to [`git-workon`](commands.md#git-workon) | | `gome` | `exec git checkout "$(git main-branch)"` — **smart**, delegates to [`git-main-branch`](commands.md#git-main-branch) |

All of the `checkout`-flavored shortcuts (`gout`, `gome`) use `git checkout`, matching this repo's existing convention, not `git switch`.
