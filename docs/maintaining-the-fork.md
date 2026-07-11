# Maintaining the fork

Back to the [README](../README.md).

This is a personal fork of [`nvie/git-toolbelt`](https://github.com/nvie/git-toolbelt) under GitHub user `sdthach` (repo: `github.com/sdthach/git-toolbelt`), extended with the `portmanteaus/` shortcut set, this `docs/` layout, and Homebrew packaging that works identically on macOS and Linux/WSL. Everything added here is additive — the upstream `git-*` scripts are left untouched so merges from upstream stay clean.

## End-state layout

```
git-toolbelt/                 # fork: github.com/sdthach/git-toolbelt
├── git-*  (~70 upstream)     # UNTOUCHED
├── portmanteaus/             # getch gull gulp gush gadd gommit gmend
│   └── gtatus giff glog granch gtash gout gome
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

`release.yml` pushes to a *different* repo (`sdthach/homebrew-tap`), which the default `GITHUB_TOKEN` can't do. One-time setup: create a **fine-grained PAT** with **contents: write** scoped to `sdthach/homebrew-tap`, and add it to this repo as a secret named `TAP_TOKEN` (`gh secret set TAP_TOKEN`). Until that exists (and the tap repo is bootstrapped), `release.yml`'s tap-update step will fail — expected, since releases are a pending follow-up.

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

Today the formula ships **`--HEAD`-only**: its stable `url`/`sha256` stanza is commented out until the first fork release.

### One-time tap bootstrap — ⏳ pending (follow-up session)

Not done yet (deferred to a machine with `brew`/`ruby` so the install can actually be tested end-to-end):

1. `gh repo create sdthach/homebrew-tap --public -d "Homebrew tap for my git-toolbelt fork"`.
2. Copy `packaging/git-toolbelt.rb` into the tap repo; commit and push.
3. Verify: `brew tap sdthach/tap && brew install --HEAD sdthach/tap/git-toolbelt`, then confirm both a `git-*` command (e.g. `git sha`) and a portmanteau (e.g. `getch`, `gush`) resolve.

### Cutting a release (per version)

Once the tap exists, releases follow the [`PUBLISHING.md`](../PUBLISHING.md) flow, automated by `.github/workflows/release.yml` (slice 05):

1. Update `CHANGELOG.md`.
2. Tag the version (`git tag vX.Y.Z`) and push it (`git push origin vX.Y.Z`).
3. The release workflow creates the GitHub release, computes the tarball `sha256`, and commits the updated `url`+`sha256` into `sdthach/homebrew-tap`'s `git-toolbelt.rb` (this cross-repo push needs a `TAP_TOKEN` secret — see slice 05).

To do it by hand instead: cut the release at `github.com/sdthach/git-toolbelt/releases`, run `wget -O - https://github.com/sdthach/git-toolbelt/archive/refs/tags/vX.Y.Z.tar.gz | sha256sum`, and update the tap formula's `url`/`sha256`.
