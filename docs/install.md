# Installation

Back to the [README](../README.md).

## Prerequisites

- **git** — required. Everything in this toolbelt is a thin wrapper around `git` plumbing/porcelain.
- **GNU coreutils (`realpath`)** — only needed by [`git-relative-path`](commands.md#git-relative-path). Native on Linux (and therefore on WSL). On macOS, install with `brew install coreutils` (the Homebrew formula pulls this in automatically as a dependency — see below).
- **[`fzf`][fzf]** — optional, only used by [`git-fixup-with`](commands.md#git-fixup-with) for its interactive commit picker. Install separately with `brew install fzf` if you want that command.
- **[`direnv`][direnv]** — optional, and only relevant if you're developing *on this repo itself* (not for regular installed use). See the dev note below.

## Installation (Homebrew)

Installation is identical on macOS and on Linux/WSL — there's a single tap and formula for both:

```console
$ brew tap sdthach/tap
$ brew install sdthach/tap/git-toolbelt
```

### `--HEAD` variant

To track the tip of the `main` branch instead of the latest tagged release (useful if you want fork changes before they're cut into a release):

```console
$ brew install --HEAD sdthach/tap/git-toolbelt
```

You can switch back to the released version later with `brew install sdthach/tap/git-toolbelt` (Homebrew will offer to switch off `--HEAD`).

## Developing on this repo (direnv note)

If you're working *inside a clone of this repo* (not installing it), the checked-in `.envrc` adds both the repo root and `portmanteaus/` to `PATH` via `direnv`, so the `git-*` scripts and the `g`+verb shortcuts resolve without installing anything. Run `direnv allow` once after cloning to opt in. This is a dev convenience only — it has no effect for people who install via Homebrew.

[fzf]: https://github.com/junegunn/fzf
[direnv]: https://direnv.net/
