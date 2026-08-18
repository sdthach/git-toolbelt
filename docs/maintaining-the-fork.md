# Maintaining the fork

Back to the [README](../README.md).

This is a personal fork of [`nvie/git-toolbelt`](https://github.com/nvie/git-toolbelt) under GitHub user `sdthach` (repo: `github.com/sdthach/git-toolbelt`), extended with the `portmanteaus/` shortcut set, this `docs/` layout, and dual mise/Homebrew distribution that works identically on macOS and Linux/WSL. Everything added here is additive — the upstream `git-*` scripts are left untouched so merges from upstream stay clean.

## Layout

```
git-toolbelt/                 # fork: github.com/sdthach/git-toolbelt
├── git-*  (62 upstream)      # UNTOUCHED, at the root, on purpose
├── git-toolbelt              # fork-only: identifies which build is installed
├── portmanteaus/             # getch gull gulp gush gadd gommit gamend
│   └── gatus giff glog granch gtash gout gome
├── docs/                     # install / commands / portmanteaus / maintaining-the-fork
├── scripts/
│   ├── build-dist.sh         # assembles the release tarball
│   └── smoke-test.sh         # builds it and exercises it like an install
├── packaging/git-toolbelt.rb # brew formula source of truth
├── .github/workflows/        # ci / upstream-sync / release
├── mise.toml                 # dev PATH + tools + lint/build/smoke/ci tasks
├── .envrc                    # direnv shim; delegates to mise
├── version.txt               # bumped by release-please
├── release-please-config.json / .release-please-manifest.json
├── README.md                 # slimmed to a hub → docs/
└── CHANGELOG.md / PUBLISHING.md / LICENSE

homebrew-tap/                 # separate repo: github.com/sdthach/homebrew-tap
└── git-toolbelt.rb           # replaced wholesale from packaging/ on each release
```

### Repo layout vs. shipped layout

They are deliberately different:

| | Repo | Release tarball |
|---|---|---|
| upstream commands | `git-cleanup`, … at the root | `bin/git-cleanup`, … |
| fork shortcuts | `portmanteaus/gadd`, … | `bin/gadd`, … |

Keeping `git-*` at the root is what makes the weekly upstream sync a no-op merge — upstream touches `git-cleanup`, this fork has `git-cleanup` at the same path, and git has nothing to reconcile. Moving them into `bin/` would make every upstream merge depend on rename detection.

The flattening happens instead in [`scripts/build-dist.sh`](../scripts/build-dist.sh) at release time, so the shipped archive gets the single `bin/` directory that installers want without the repo paying for it.

## How the two install paths work

mise and Homebrew install the **same artifact**: the `git-toolbelt-<version>.tar.gz` release asset that [`scripts/build-dist.sh`](../scripts/build-dist.sh) produces. One tarball, one `sha256`, one `bin/` layout — the paths cannot drift apart, and a bug reproduced under one is a bug under the other.

### mise

`mise use -g github:sdthach/git-toolbelt` works with **zero tool options**, and three details in the release are what make that true. All three are asserted by CI, so they can't quietly regress:

1. **There is a release asset at all.** mise's github backend downloads release *assets*; GitHub's auto-generated "Source code (tar.gz)" links are not assets and are invisible to it. A tag alone is not an installable release.
2. **The archive has a top-level `bin/`.** With no `bin_path` option set, mise's binary-path lookup uses `<install_path>/bin` when that directory exists. The tarball also carries files and a second directory at its root, so mise's automatic `strip_components` heuristic (which fires only for a single root directory with no files) can't move things around.
3. **The asset is named `git-toolbelt-<version>.tar.gz`.** mise scores assets for platform fit and discards anything scoring ≤ 0. This name scores +10 as a recognized archive format and +20 for matching the repo name, with no OS or architecture token to mismatch against — so the one platform-independent build is selected on every OS and arch.

A `git-toolbelt-<version>.tar.gz.sha256` asset rides along: mise looks for exactly that name and verifies the download against it. Its `.sha256` extension is heavily penalized in asset scoring, so it can never be mistaken for the tool itself. Releases also carry GitHub build-provenance attestations, which mise verifies when present; `github_attestations = false` on the tool is the escape hatch if that service ever blocks an install.

### Homebrew

The formula's `url` points at that same release asset, so `def install` is just `bin.install Dir["bin/*"]`. A `--HEAD` build gets the repo layout instead of the tarball, so the formula falls back to installing `git-*` and `portmanteaus/*` separately when there's no `bin/` — that branch is what keeps `--HEAD` working.

[`packaging/git-toolbelt.rb`](../packaging/git-toolbelt.rb) is the source of truth. On each release the workflow copies it over the tap's copy wholesale and rewrites only `url` and `sha256`, so formula edits (dependencies, the `test do` block) propagate. Earlier this was a patch-in-place, and the tap accumulated two commits — a test-block fix and a version pin — that never made it back here; the copy-wholesale approach is what prevents that recurring.

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
- **`release.yml`** — on every push to `main`. Runs release-please, which maintains the release PR; when that PR merges, the same run builds the tarball and its `.sha256`, attests build provenance, attaches both to the release release-please just created, and bumps the tap formula. Only the tap bump needs a secret (`TAP_TOKEN`), and it skips gracefully without one.

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

## Versioning and releases

Versions are computed by [release-please](https://github.com/googleapis/release-please) from conventional-commit subjects on `main`, not chosen by hand. It keeps a `chore: release X.Y.Z` PR open with the computed version and CHANGELOG diff; merging that PR tags, releases, and triggers the artifact build. `version.txt` and `CHANGELOG.md` are maintained by it — don't hand-edit them outside its PR.

This has one consequence worth internalizing: **a commit with a non-conventional subject is invisible to versioning.** It gets no CHANGELOG entry and triggers no bump. Since upstream's commits are all free-form, the `upstream-sync` PR is titled `feat: sync upstream …` and is meant to be squash-merged so that one classified subject is what lands.

`.release-please-manifest.json` seeds the version line at `1.12.0` — the upstream release this fork forked from — so the breaking mise/Homebrew change computes `2.0.0`. There is no `v1.12.0` *tag*, though: upstream's newest tag is `v1.11.0`, and 1.12.0 exists only as an untagged CHANGELOG entry on its main. `last-release-sha` in [`release-please-config.json`](../release-please-config.json) therefore pins where that notional release sat (`9d8a133`, the last upstream commit before the fork's first), so release-please bounds its scan at the fork boundary instead of walking the entire history. Once `v2.0.0` is tagged, release-please uses that tag and the pin is inert.

See **[`PUBLISHING.md`](../PUBLISHING.md)** for the step-by-step runbook, the conventional-commit reference table, the `TAP_TOKEN` setup, and how to build a release by hand if Actions is unavailable.
