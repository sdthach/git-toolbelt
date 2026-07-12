# Installation

Back to the [README](../README.md).

## Prerequisites

- **git** — required. Everything in this toolbelt is a thin wrapper around `git` plumbing/porcelain.
- **GNU coreutils (`realpath`)** — only needed by [`git-relative-path`](commands.md#git-relative-path). Native on Linux (and therefore on WSL). On macOS, install with `brew install coreutils` (the Homebrew formula pulls this in automatically as a dependency — see below).
- **[`fzf`][fzf]** — optional, only used by [`git-fixup-with`](commands.md#git-fixup-with) for its interactive commit picker. Install separately with `brew install fzf` if you want that command.
- **[`direnv`][direnv]** — optional, and only relevant if you're developing *on this repo itself* (not for regular installed use). See the dev note below.

## Installation (Homebrew)

Installation is identical on macOS and on Linux/WSL — there's a single tap and formula for both.

> **Status:** the tap repo (`sdthach/homebrew-tap`) and the first tagged release haven't been cut yet, so today the formula is **`--HEAD`-only** (see option 1). Option 2 (a pinned stable release) becomes available once the first `v*` tag is pushed and the release workflow fills in the formula's `url`/`sha256`.

### Option 1 — `--HEAD` (available now)

Tracks the tip of `main`, so you get fork changes immediately:

```console
$ brew tap sdthach/tap
$ brew install --HEAD sdthach/tap/git-toolbelt
```

### Option 2 — stable release (after the first release is cut)

Installs the latest tagged version:

```console
$ brew install sdthach/tap/git-toolbelt
```

You can move between them later — `brew install --HEAD …` to switch to the tip, or `brew install …` to switch back to the released version (Homebrew will offer to switch off `--HEAD`).

## Developing on this repo (direnv note)

If you're working *inside a clone of this repo* (not installing it), the checked-in `.envrc` adds both the repo root and `portmanteaus/` to `PATH` via `direnv`, so the `git-*` scripts and the `g`+verb shortcuts resolve without installing anything. Run `direnv allow` once after cloning to opt in. This is a dev convenience only — it has no effect for people who install via Homebrew.

[fzf]: https://github.com/junegunn/fzf
[direnv]: https://direnv.net/
