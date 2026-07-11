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

## Syncing from upstream

Pull upstream changes into the fork's `main` periodically (manually today; slice 05 adds a scheduled workflow for this):

```console
$ git fetch upstream
$ git checkout main
$ git merge upstream/main
$ git push origin main
```

Because the upstream `git-*` scripts are never modified in this fork, these merges should stay fast-forward or conflict-free in the common case. Conflicts would only arise if a fork-only file (docs, portmanteaus, packaging) happens to collide with an upstream rename/move — unlikely given the additive-only approach.

## Releasing / tap ops

Release mechanics largely follow the existing [`PUBLISHING.md`](../PUBLISHING.md) flow (tag, push tag, cut a GitHub release, compute the tarball's `sha256`), adjusted for the fork's own tap:

1. Update `CHANGELOG.md`.
2. Tag the version (`git tag vX.Y.Z`) and push it (`git push origin --tags`).
3. Cut a release from the tag at `github.com/sdthach/git-toolbelt/releases`.
4. Compute the tarball hash: `wget -O - https://github.com/sdthach/git-toolbelt/archive/vX.Y.Z.tar.gz | sha256sum`.
5. In the `homebrew-tap` repo, update `git-toolbelt.rb`'s `url` and `sha256`, commit, and push.

Slice 04 defines the formula itself (`packaging/git-toolbelt.rb`) and slice 05 automates lint/CI and the upstream sync above — this page will grow with more detail once those land.
