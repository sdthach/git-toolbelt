# Maintaining the fork

Back to the [README](../README.md).

This is a personal fork of [`nvie/git-toolbelt`](https://github.com/nvie/git-toolbelt) under GitHub user `sdthach` (repo: `github.com/sdthach/git-toolbelt`), extended with the `portmanteaus/` shortcut set, this `docs/` layout, and Homebrew packaging that works identically on macOS and Linux/WSL. Everything added here is additive — the upstream `git-*` scripts are left untouched so merges from upstream stay clean.

## End-state layout

```
git-toolbelt/                 # fork: github.com/sdthach/git-toolbelt
├── git-*  (~70 upstream)     # UNTOUCHED
├── portmanteaus/             # getch gull gulp gush gadd gommit gamend
│   └── gatus giff glog granch gtash gout gome
├── docs/                     # install / commands / portmanteaus / maintaining-the-fork
├── packaging/git-toolbelt.rb # brew formula source of truth
├── .github/workflows/        # lint / upstream-sync / release
├── .envrc                    # PATH_add .  +  PATH_add portmanteaus
├── README.md                 # slimmed to a hub → docs/
└── CHANGELOG.md / PUBLISHING.md / LICENSE

homebrew-tap/                 # separate repo: github.com/sdthach/homebrew-tap
└── git-toolbelt.rb
```

## Remotes

- `origin` → the fork (`github.com/sdthach/git-toolbelt`) — read/write, this is where feature branches and PRs land.
- `upstream` → `github.com/nvie/git-toolbelt`, **fetch-only** — pulls in upstream fixes and features, push disabled so there's no risk of accidentally pushing to the original author's repo.

## CI/CD (GitHub Actions)

Three workflows live in `.github/workflows/`:

- **`lint.yml`** — on every push/PR. Runs `shellcheck` on `portmanteaus/*` at full severity (the fork's own scripts) and on the upstream `git-*` scripts at `--severity=error` only (they carry pre-existing style/info/warning findings that we deliberately don't "fix", to keep upstream merges clean).
- **`upstream-sync.yml`** — weekly cron + manual `workflow_dispatch`. Pushes `upstream/main`'s tip to an `upstream-sync/<date>` branch and opens a PR into `main` (never an auto-merge — conflicts with fork-only files surface in the PR for review).
- **`release.yml`** — on a pushed `v*` tag. Creates the GitHub release, hashes the source tarball, and commits the new `url`+`sha256` into the tap formula.

### Manual secret: `TAP_TOKEN`

`release.yml` pushes to a *different* repo (`sdthach/homebrew-tap`), which the default `GITHUB_TOKEN` can't do. One-time setup: create a **fine-grained PAT** with **contents: write** scoped to `sdthach/homebrew-tap`, and add it to this repo as a secret named `TAP_TOKEN` (`gh secret set TAP_TOKEN`).

Until `TAP_TOKEN` is configured, `release.yml`'s tap-update step is **skipped gracefully** (the GitHub release is still created, with a `::notice::` in the run) — the `v1.12.0-fork.1` tap update was done by hand. Set the token to automate the tap bump on future releases.

## Syncing from upstream

The `upstream-sync` workflow automates this weekly, but you can also do it by hand:

```console
$ git fetch upstream
$ git checkout main
$ git merge upstream/main
$ git push origin main
```

Because the upstream `git-*` scripts are never modified in this fork, these merges should stay fast-forward or conflict-free in the common case. Conflicts would only arise if a fork-only file (docs, portmanteaus, packaging) happens to collide with an upstream rename/move — unlikely given the additive-only approach.

## Homebrew tap

The formula source of truth is [`packaging/git-toolbelt.rb`](../packaging/git-toolbelt.rb) in this repo; the tap repo (`github.com/sdthach/homebrew-tap`) holds a synced copy that `brew` actually reads.

### Install modes

The formula supports two install paths (see [`docs/install.md`](install.md)):

- **`--HEAD`** — installs from the tip of `main`. Available as soon as the tap repo exists.
- **Stable** — installs a pinned `vX.Y.Z` tarball. Requires the formula's `url`/`sha256` to be filled, which happens the first time a release is cut.

Both modes are live as of `v1.12.0-fork.1`. In `packaging/git-toolbelt.rb` (the source of truth) the stable `url`/`sha256`/`version` stanza is kept commented as a template; the tap copy carries the populated values.

> **Version pin gotcha:** Homebrew mis-parses a `-fork.N` tag (e.g. `v1.12.0-fork.1`) down to a bare `1`, which breaks `brew upgrade` detection. The formula therefore pins `version "1.12.0-fork.1"` explicitly, and `release.yml` rewrites that line (alongside `url`/`sha256`) on each release.

### One-time tap bootstrap — ✅ done (v1.12.0-fork.1)

The tap (`github.com/sdthach/homebrew-tap`) is published and seeded, and both install paths were smoke-tested end-to-end on Linux/WSL (`brew install` stable + `--HEAD`, and `brew test` passing). For reference, the bootstrap was:

1. `gh repo create sdthach/homebrew-tap --public` (empty).
2. Seed `git-toolbelt.rb` (HEAD + populated stable stanza) and a README; push to `main`.
3. Verify: `brew install sdthach/tap/git-toolbelt` (and `--HEAD`), confirm a `git-*` command (e.g. `git sha`) and a portmanteau (e.g. `getch`, `gush`) resolve, and `brew test git-toolbelt` passes.

The tap's `main` is protected against force-push/deletion (but not behind a PR gate, so `release.yml` can push formula bumps directly).

### Cutting a release (per version)

Once the tap exists, releases follow the [`PUBLISHING.md`](../PUBLISHING.md) flow, automated by `.github/workflows/release.yml` (slice 05):

1. Update `CHANGELOG.md`.
2. Tag the version (`git tag vX.Y.Z`) and push it (`git push origin vX.Y.Z`).
3. The release workflow creates the GitHub release, computes the tarball `sha256`, and commits the updated `url`+`sha256` into `sdthach/homebrew-tap`'s `git-toolbelt.rb` (this cross-repo push needs a `TAP_TOKEN` secret — see slice 05).

To do it by hand instead: cut the release at `github.com/sdthach/git-toolbelt/releases`, run `wget -O - https://github.com/sdthach/git-toolbelt/archive/refs/tags/vX.Y.Z.tar.gz | sha256sum`, and update the tap formula's `url`/`sha256`.
