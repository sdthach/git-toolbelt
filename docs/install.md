# Installation

Back to the [README](../README.md).

## Prerequisites

- **[mise](https://mise.jdx.dev) or [Homebrew](https://brew.sh)** — either one installs the toolbelt; both install the exact same build. For mise: `curl https://mise.run | sh`, then [activate it in your shell](https://mise.jdx.dev/getting-started.html).
- **git** — required. Everything in this toolbelt is a thin wrapper around `git` plumbing/porcelain.
- **GNU coreutils (`realpath`)** — only needed by [`git-relative-path`](commands.md#git-relative-path). Native on Linux (and therefore on WSL). On macOS: `mise use -g coreutils` or `brew install coreutils`.
- **[`fzf`][fzf]** — optional, only used by [`git-fixup-with`](commands.md#git-fixup-with) for its interactive commit picker. `mise use -g fzf` if you want that command.

## Install

The commands are pure POSIX `sh`, so there is one platform-independent build, and the same install works on macOS, Linux, and WSL. Pick whichever package manager you already use — both consume the identical release tarball, so neither is "the real one".

### Option 1 — mise

```console
$ mise use -g github:sdthach/git-toolbelt
```

That records the tool in `~/.config/mise/config.toml`:

```toml
[tools]
"github:sdthach/git-toolbelt" = "latest"
```

All 76 commands land on `PATH` — the `git-*` scripts resolve as `git <verb>` subcommands, and the `g`+verb shortcuts as standalone commands:

```console
$ git main-branch
main
$ gatus
On branch main
...
```

Pin a version with `mise use -g github:sdthach/git-toolbelt@2.0.0`, or drop the `-g` and run it inside a project to pin it in that project's `mise.toml`. Upgrade with `mise upgrade github:sdthach/git-toolbelt`.

### Option 2 — Homebrew

```console
$ brew install sdthach/tap/git-toolbelt
```

Or track the tip of `main`, ahead of the tagged releases:

```console
$ brew tap sdthach/tap
$ brew install --HEAD sdthach/tap/git-toolbelt
```

You can move between them later — `brew install --HEAD …` to switch to the tip, or `brew install …` to switch back to the released version.

### Why mise needs no tool options

The release tarball ships its commands in a top-level `bin/` directory, which is exactly what mise's github backend looks for when no `bin_path` is set. Releases also carry a `.sha256` asset that mise matches by name and verifies automatically, plus GitHub build-provenance attestations. If GitHub's attestation service is ever down and blocks an install, the escape hatch is `github_attestations = false` on the tool.

The Homebrew formula points its `url` at that same tarball and installs the same `bin/`, so the two paths cannot drift apart — there is one artifact and one `sha256` per release.

## Developing on this repo

If you're working *inside a clone of this repo* rather than installing it, the checked-in [`mise.toml`](../mise.toml) puts the repo root and `portmanteaus/` on `PATH`, so the scripts resolve without installing anything, and it defines the lint/build/test tasks:

```console
$ mise trust        # once, after cloning
$ mise install      # shellcheck, yamllint
$ mise run ci       # everything CI runs: lint + smoke test
```

`direnv` users get the same environment via the checked-in `.envrc` (`direnv allow` once) — it delegates to mise rather than duplicating the `PATH` list.

[fzf]: https://github.com/junegunn/fzf
