# Maintaining the fork

Back to the [README](../README.md).

This is a personal fork of [`nvie/git-toolbelt`](https://github.com/nvie/git-toolbelt) under GitHub user `sdthach` (repo: `github.com/sdthach/git-toolbelt`), extended with the `portmanteaus/` shortcut set, this `docs/` layout, and mise-based distribution that works identically on macOS and Linux/WSL. Everything added here is additive — the upstream `git-*` scripts are left untouched so merges from upstream stay clean.

## Layout

```
git-toolbelt/                 # fork: github.com/sdthach/git-toolbelt
├── git-*  (62 upstream)      # UNTOUCHED, at the root, on purpose
├── portmanteaus/             # getch gull gulp gush gadd gommit gamend
│   └── gatus giff glog granch gtash gout gome
├── docs/                     # install / commands / portmanteaus / maintaining-the-fork
├── scripts/
│   ├── build-dist.sh         # assembles the release tarball
│   └── smoke-test.sh         # builds it and exercises it like an install
├── .github/workflows/        # ci / upstream-sync / release
├── mise.toml                 # dev PATH + tools + lint/build/smoke/ci tasks
├── .envrc                    # direnv shim; delegates to mise
├── README.md                 # slimmed to a hub → docs/
└── CHANGELOG.md / PUBLISHING.md / LICENSE
```

### Repo layout vs. shipped layout

They are deliberately different:

| | Repo | Release tarball |
|---|---|---|
| upstream commands | `git-cleanup`, … at the root | `bin/git-cleanup`, … |
| fork shortcuts | `portmanteaus/gadd`, … | `bin/gadd`, … |

Keeping `git-*` at the root is what makes the weekly upstream sync a no-op merge — upstream touches `git-cleanup`, this fork has `git-cleanup` at the same path, and git has nothing to reconcile. Moving them into `bin/` would make every upstream merge depend on rename detection.

The flattening happens instead in [`scripts/build-dist.sh`](../scripts/build-dist.sh) at release time, so the shipped archive gets the single `bin/` directory that installers want without the repo paying for it.

## How mise installs this

`mise use -g github:sdthach/git-toolbelt` works with **zero tool options**, and three details in the release are what make that true. All three are asserted by CI, so they can't quietly regress:

1. **There is a release asset at all.** mise's github backend downloads release *assets*; GitHub's auto-generated "Source code (tar.gz)" links are not assets and are invisible to it. A tag alone is not an installable release.
2. **The archive has a top-level `bin/`.** With no `bin_path` option set, mise's binary-path lookup uses `<install_path>/bin` when that directory exists. The tarball also carries files and a second directory at its root, so mise's automatic `strip_components` heuristic (which fires only for a single root directory with no files) can't move things around.
3. **The asset is named `git-toolbelt-<version>.tar.gz`.** mise scores assets for platform fit and discards anything scoring ≤ 0. This name scores +10 as a recognized archive format and +20 for matching the repo name, with no OS or architecture token to mismatch against — so the one platform-independent build is selected on every OS and arch.

A `git-toolbelt-<version>.tar.gz.sha256` asset rides along: mise looks for exactly that name and verifies the download against it. Its `.sha256` extension is heavily penalized in asset scoring, so it can never be mistaken for the tool itself. Releases also carry GitHub build-provenance attestations, which mise verifies when present; `github_attestations = false` on the tool is the escape hatch if that service ever blocks an install.

Because everything here is POSIX `sh`, there is one noarch build rather than a matrix.

## Remotes

- `origin` → the fork (`github.com/sdthach/git-toolbelt`) — read/write, this is where feature branches and PRs land.
- `upstream` → `github.com/nvie/git-toolbelt`, **fetch-only** — pulls in upstream fixes and features, push disabled so there's no risk of accidentally pushing to the original author's repo.

## CI/CD (GitHub Actions)

Three workflows live in `.github/workflows/`:

- **`ci.yml`** — on every push/PR. Installs mise and runs `mise run ci`, which is the same command you run locally, so CI and local can't drift:
  - `lint` — `shellcheck` on `portmanteaus/*` and `scripts/*.sh` at full severity (the fork's own scripts) and on the upstream `git-*` scripts at `--severity=error` only (they carry pre-existing style/info/warning findings that we deliberately don't "fix", to keep upstream merges clean), plus `yamllint` on the workflows.
  - `smoke` — builds the release tarball, extracts it, and runs `git main-branch` / `git current-branch` off its `bin/`, checking the archive shape and that every shipped command is executable. This is what stops a broken release from being discovered by users.
- **`upstream-sync.yml`** — weekly cron + manual `workflow_dispatch`. Pushes `upstream/main`'s tip to an `upstream-sync/<date>` branch and opens a PR into `main` (never an auto-merge — conflicts with fork-only files surface in the PR for review).
- **`release.yml`** — on a pushed `v*` tag. Validates the tag shape, builds the tarball and its `.sha256`, attests build provenance, and creates the GitHub release with both attached. No repository secrets are required.

## Syncing from upstream

The `upstream-sync` workflow automates this weekly, but you can also do it by hand:

```console
$ git fetch upstream
$ git checkout main
$ git merge upstream/main
$ git push origin main
```

Because the upstream `git-*` scripts are never modified — and never moved — in this fork, these merges stay fast-forward or conflict-free in the common case. Conflicts would only arise if a fork-only file (docs, portmanteaus, scripts) happens to collide with an upstream rename, which is unlikely given the additive-only approach.

If upstream adds a new `git-*` command, it needs no packaging work: `build-dist.sh` globs `git-*`, so it ships automatically. It does deserve an entry in [`docs/commands.md`](commands.md) and the README index.

## Releases

See **[`PUBLISHING.md`](../PUBLISHING.md)** for the step-by-step runbook — version numbering (plain `vX.Y.Z`, enforced by the workflow), the CHANGELOG/tag steps, and how to build the asset by hand if Actions is unavailable.

### Homebrew (retired)

Earlier versions of this fork shipped through a Homebrew tap (`sdthach/homebrew-tap`) with a `packaging/git-toolbelt.rb` formula. That path is retired in favour of mise: it needed a second repo, a `TAP_TOKEN` secret to push across repos, and an explicit `version` pin to work around Homebrew mis-parsing the old `-fork.N` tags. The tap repo still exists and is untouched by this repo's automation — archive or delete it when convenient, and note that anyone still on `brew install sdthach/tap/git-toolbelt` will stay pinned at `v1.12.0-fork.1` until they switch to mise.
