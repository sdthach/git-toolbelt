# Maintaining the fork

Back to the [README](../README.md).

This is a personal fork of [`nvie/git-toolbelt`](https://github.com/nvie/git-toolbelt) under GitHub user `sdthach` (repo: `github.com/sdthach/git-toolbelt`), extended with the `portmanteaus/` shortcut set, the `bare-worktree/` bare-repo + worktree commands, this `docs/` layout, and dual mise/Homebrew distribution that works identically on macOS and Linux/WSL. Everything added here is additive — the upstream `git-*` scripts are kept as upstream has them so merges from upstream stay clean, apart from fixes on their way upstream, listed under [Temporary divergences from upstream](#temporary-divergences-from-upstream).

> The reasoning behind the current setup, and the failures that shaped it, are recorded in [distribution-rework](distribution-rework.md).

## Layout

```
git-toolbelt/                 # fork: github.com/sdthach/git-toolbelt
├── git-*  (60 upstream)      # as upstream has them, at the root, on purpose
├── git-toolbelt              # fork-only: identifies which build is installed
├── portmanteaus/             # getch gull gulp gush gadd gommit gamend
│   └── gatus giff glog granch gtash gout gome
├── bare-worktree/            # fork-only: git-{clone,init,convert,switch}-worktree,
│                             #   git-bare-worktree, git-bwt + README, docs/, *.example
├── docs/                     # install / commands / portmanteaus / maintaining-the-fork
├── scripts/
│   ├── build-dist.sh         # assembles the release tarball
│   ├── smoke-test.sh         # builds it and exercises it like an install
│   └── test-bare-worktree.sh # end-to-end tests for bare-worktree/ (run by smoke)
├── packaging/git-toolbelt.rb # brew formula source of truth
├── test/                     # sandboxed script and fork sync-workflow tests
├── .github/workflows/        # ci / Test / upstream-sync / release
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
| bare-worktree commands | `bare-worktree/git-clone-worktree`, … | `bin/git-clone-worktree`, … |
| bare-worktree docs and samples | `bare-worktree/README.md`, `bare-worktree/docs/*.md`, `bare-worktree/*.example` | `share/git-toolbelt/bare-worktree/…` |

Keeping `git-*` at the root lets the weekly sync apply upstream changes at their existing paths. Temporary fixes can still conflict with upstream edits to the same code. Moving the scripts into `bin/` would make every sync depend on rename detection.

The flattening happens instead in [`scripts/build-dist.sh`](../scripts/build-dist.sh) at release time, so the shipped archive gets the single `bin/` directory that installers want without the repo paying for it. Only `bare-worktree/git-*` goes into `bin/`; the folder's README, `docs/*.md` and `.example` files go to `share/git-toolbelt/bare-worktree/`, and its `docs/plans/` is repo-only and not shipped.

## How the two install paths work

mise and Homebrew install the **same artifact**: the `git-toolbelt-<version>.tar.gz` release asset that [`scripts/build-dist.sh`](../scripts/build-dist.sh) produces. One tarball, one `sha256`, one `bin/` layout — the paths cannot drift apart, and a bug reproduced under one is a bug under the other.

### mise

`mise use -g github:sdthach/git-toolbelt` works with **zero tool options**, and three details in the release are what make that true. All three are asserted by CI, so they can't quietly regress:

1. **There is a release asset at all.** mise's github backend downloads release *assets*; GitHub's auto-generated "Source code (tar.gz)" links are not assets and are invisible to it. A tag alone is not an installable release.
2. **The archive has a top-level `bin/`.** With no `bin_path` option set, mise's binary-path lookup uses `<install_path>/bin` when that directory exists. The tarball also carries files and more directories (`docs/`, `share/`) at its root, so mise's automatic `strip_components` heuristic (which fires only for a single root directory with no files) can't move things around.
3. **The asset is named `git-toolbelt-<version>.tar.gz`.** mise scores assets for platform fit and discards anything scoring ≤ 0. This name scores +10 as a recognized archive format and +20 for matching the repo name, with no OS or architecture token to mismatch against — so the one platform-independent build is selected on every OS and arch.

A `git-toolbelt-<version>.tar.gz.sha256` asset rides along: mise looks for exactly that name and verifies the download against it. Its `.sha256` extension is heavily penalized in asset scoring, so it can never be mistaken for the tool itself. Releases also carry GitHub build-provenance attestations, which mise verifies when present; `github_attestations = false` on the tool is the escape hatch if that service ever blocks an install.

### Homebrew

The formula's `url` points at that same release asset, so `def install` is just `bin.install Dir["bin/*"]` plus `pkgshare.install "share/git-toolbelt/bare-worktree"` for the bare-worktree docs and samples. A `--HEAD` build gets the repo layout instead of the tarball, so the formula falls back to installing `git-*`, `portmanteaus/*` and `bare-worktree/git-*` separately when there's no `bin/`, and copies the bare-worktree README, samples and `docs/*.md` into `pkgshare` itself — that branch is what keeps `--HEAD` working. Worktrunk is not a `depends_on`: only the bare-worktree commands need it, so the formula's `caveats` say how to install it instead.

[`packaging/git-toolbelt.rb`](../packaging/git-toolbelt.rb) is the source of truth. On each release the workflow copies it over the tap's copy wholesale and rewrites only `url` and `sha256`, so formula edits (dependencies, the `test do` block) propagate. Earlier this was a patch-in-place, and the tap accumulated two commits — a test-block fix and a version pin — that never made it back here; the copy-wholesale approach is what prevents that recurring.

Because everything here is POSIX `sh`, there is one noarch build rather than a matrix.

## Remotes

- `origin` → the fork (`github.com/sdthach/git-toolbelt`) — read/write, this is where feature branches and PRs land.
- `upstream` → `github.com/nvie/git-toolbelt`, **fetch-only** — pulls in upstream fixes and features, push disabled so there's no risk of accidentally pushing to the original author's repo.

Run **`mise run setup`** in a fresh clone to put both in place ([`scripts/dev-setup.sh`](../scripts/dev-setup.sh)); it is idempotent, so re-running is harmless. These settings live in `.git/config`, which is untracked, so they cannot travel with the repo and are lost on every clone. That is exactly how they rot: the `upstream` push URL was documented as disabled here long before it actually was, and `git push upstream main` would have reached nvie's repo for real. A task that can be run beats a paragraph that has to be remembered.

## Commit signing

`main` is governed by the `main_protection` ruleset, which requires **verified signatures**. An unsigned commit blocks its own PR no matter how green CI is, and GitHub draws a distinction that is easy to miss:

> An SSH key registered for **authentication** does not verify commit signatures. The same key has to be added a second time as a **signing** key. A key that pushes fine can still leave every commit "Unverified".

Set a key up once, globally, and `mise run setup` enables signing in each clone:

```console
$ git config --global gpg.format ssh
$ git config --global user.signingkey ~/.ssh/<key>.pub
$ gh auth refresh -h github.com -s admin:ssh_signing_key
$ gh ssh-key add ~/.ssh/<key>.pub --type signing --title "<machine> signing"
```

GPG works equally well — `git config --global user.signingkey <key-id>` plus `gpg --armor --export <key-id> | gh gpg-key add -`. Either way, check it took with `gh api /users/<you>/ssh_signing_keys --jq length` (or `/gpg_keys`); a `0` there is the reason signatures aren't verifying.

### When signatures still say "Unverified"

GitHub matches a commit to the account that owns its **committer email**, then looks for signing keys *on that account*. Register a key on one account and commit under an email owned by another, and every commit reports `unknown_key` — with matching fingerprints, a correct key type, and registration long predating the commit. Nothing in the UI names the mismatch.

This repo hit exactly that: commits carried `sambo.thach@gmail.com`, which belongs to the `sambothach` account, while the signing keys lived on `sdthach`, the account that owns the repo. Commits are now authored as `106501462+sdthach@users.noreply.github.com` — a noreply address is verified by definition and cannot collide with another account.

Diagnose it in one call, which reports the account GitHub attributed the commit to:

```console
$ gh api repos/sdthach/git-toolbelt/commits/<sha> \
    --jq '"\(.author.login)  \(.commit.verification.reason)"'
sdthach  valid
```

If that login is not the account holding your signing keys, the email is the problem, not the key.

Commits that GitHub itself creates — squash merges, and release-please's changelog commit — are signed by GitHub and satisfy the rule on their own. Only commits authored locally need your key.

## CI/CD (GitHub Actions)

Four workflows live in `.github/workflows/`:

- **`ci.yml`** — on every push/PR. Three jobs, each running one mise task, so a failure names itself in the checks list. They are the same tasks `mise run ci` runs locally, so CI and local can't drift:
  - `shellcheck` — full severity for the fork's own scripts (`portmanteaus/*`, `bare-worktree/git-*`, `scripts/*.sh`, `git-toolbelt`), `--severity=error` for the upstream `git-*` scripts, which carry pre-existing style/info/warning findings we deliberately don't "fix" so upstream merges stay clean.
  - `yamllint` — the workflows, tuned by `.yamllint`.
  - `smoke` — builds the release tarball, extracts it, and runs commands off its `bin/`, checking the archive shape (including the `share/git-toolbelt/bare-worktree/` docs and samples) and that every shipped command is executable, then runs `scripts/test-bare-worktree.sh`. The retired `scripts/test-git-modified.sh` is no longer run, and this job does not need full Git history.

  > **Job names are load-bearing.** Branch protection on `main` requires the status check named `shellcheck`. A required check that never reports is never satisfied, so renaming that job silently blocks every future PR — including release-please's release PR. Update the branch protection rule before renaming.

- **`test.yml`** — runs `make test` on Linux and macOS for PRs and pushes to `main`. It covers upstream scripts, the fork's filename/conflict regression tests, and the sync workflow's behavior with Issues enabled or disabled. GitHub calls in the workflow tests are stubbed; the tests do not create remote PRs or issues. Run this suite separately from `mise run ci`, using the dependencies in [install.md](install.md#upstreams-test-suite).
- **`upstream-sync.yml`** — Mondays at 06:00 UTC + manual `workflow_dispatch`. Counts upstream commits after the one recorded in [`.upstream-sync-base`](../.upstream-sync-base), and does nothing if there are none, a PR from `upstream-sync/…` or `chore/upstream-sync-…` is open, or an `upstream sync: …` issue is open. Otherwise it applies only upstream's changes since that base onto `main`, leaving out the fork's README. A clean application opens a PR containing the changes and the updated base. Conflicts push nothing: if Issues are enabled, the workflow opens a manual-sync issue; if they are disabled (as on this fork), it fails the run and puts the conflicting files, commits, and manual-sync instructions in the run summary. The next run retries when no sync PR or issue is open. Never an auto-merge.
- **`release.yml`** — on every push to `main`. Runs release-please, which maintains the release PR; when that PR merges, the same run builds the tarball and its `.sha256`, attests build provenance, attaches both to the release release-please just created, and bumps the tap formula. Only the tap bump needs a secret (`TAP_TOKEN`), and it skips gracefully without one.

## Review policy

`main` is governed by the `main_protection` ruleset. [`.github/CODEOWNERS`](../.github/CODEOWNERS) assigns every path to `@sdthach`, and the ruleset requires code-owner review — so approving a change into `main` is one person's call, and remains so if collaborators are added later.

The requirement only has meaning while that file exists. With no `CODEOWNERS`, a repository has no code owners, and `require_code_owner_review` blocks every pull request without granting anyone the ability to unblock it. **Deleting or emptying that file silently converts the rule from "one approver" into "nobody can merge".**

Since GitHub does not let anyone approve their own pull request, the sole maintainer's own PRs are merged using the admin bypass the ruleset grants (`gh pr merge <n> --squash --admin`). Expected, not a workaround.

## Syncing from upstream

`main` requires linear history and verified signatures, and upstream's commits are mostly unsigned. So a sync never merges upstream's history: it lands as **one squash commit**, and [`.upstream-sync-base`](../.upstream-sync-base) records which upstream commit it brought in. Without that file, `git rev-list origin/main..upstream/main` would keep counting the same upstream commits after every sync, and the workflow would open a duplicate PR every week (it did, nine times, in 2026).

The workflow prepares clean sync PRs; a maintainer still reviews them and resolves signing requirements before merging. When it reports conflicts, sync by hand:

```console
$ git fetch origin main
$ git fetch upstream main
$ git switch -c upstream-sync/manual-<sha> origin/main
$ base="$(cat .upstream-sync-base)"
$ tip="$(git rev-parse upstream/main)"
$ git diff --binary "$base" "$tip" -- . ':(exclude)README.md' \
    | git apply --3way --index --allow-empty
$ # resolve any conflicts (git status shows them as unmerged)
$ git diff "$base" "$tip" -- README.md
$ # port relevant README changes into docs/commands.md or docs/install.md
$ printf '%s\n' "$tip" > .upstream-sync-base
$ git add -A && git commit -S -m "feat: sync upstream nvie/git-toolbelt to <sha>"
$ git push -u origin HEAD                # open a PR; close any manual-sync issue after merging
```

Apply only upstream's changes since the saved `$base`, and leave out `README.md`: port upstream's README changes into [`docs/commands.md`](commands.md) or [`docs/install.md`](install.md) before advancing `.upstream-sync-base`. `--allow-empty` handles updates that only change the excluded README; the automated PR flags those changes for porting. Don't use `git merge --squash upstream/main`: because syncs are squashed, git still thinks the fork and upstream last met at `9d8a133`. It would replay every upstream change since then, and report conflicts on files an earlier sync already brought in (the 2026-11-13 sync hit this with `Makefile`, `CHANGELOG.md` and `.envrc`).

Use `fix:` if the sync is fixes only, and `feat!:` if upstream removed or renamed commands. When resolving, prefer upstream's root `git-*` scripts except for the [temporary divergences](#temporary-divergences-from-upstream): keep those guards until upstream covers the same cases and their regression tests pass. Keep the fork's `README.md`, port relevant upstream documentation into `docs/`, and update command counts when commands are added or removed.

Squashing does not prevent future upstream updates: `.upstream-sync-base` records which upstream changes were already applied. Future changes are applied with a three-way merge, so unrelated edits can retain the fork's fixes. Edits to the same code may require manual resolution. The excluded README is always reviewed separately.

If upstream adds a new `git-*` command, it needs no packaging work: `build-dist.sh` globs `git-*`, so it ships automatically. It does deserve an entry in [`docs/commands.md`](commands.md) and the README index.

## Temporary divergences from upstream

A root `git-*` script is changed here only to carry a fix that has been offered upstream, and only until upstream has it. Each one is listed here, so the sync that brings in upstream's fix knows to drop it.

- **`git-modified`.** Preserve the newline-filename guard and include add/add (`AA`) conflicts in `-u` and `-uq`. Upstream's `a484804` still splits newline-containing names into fake status records and misses `AA` conflicts. Keep these fixes until upstream handles both cases; `test/git-modified.bats` covers them.
- **`git-modified-since`.** Skip newline-containing names with a warning (silently with `-q`) instead of splitting them into separate paths. `test/git-modified-since.bats` covers the same guard for branch comparisons.

Both guards also skip names containing a literal SOH byte, which is used to preserve record boundaries in POSIX `sh`. Upstream's fixes for quoted filenames and uutils `realpath` are retained. The fork's old `scripts/test-git-modified.sh` remains retired; the regression tests now run in upstream's sandboxed bats suite.

## Versioning and releases

Versions are computed by [release-please](https://github.com/googleapis/release-please) from conventional-commit subjects on `main`, not chosen by hand. It keeps a `chore: release X.Y.Z` PR open with the computed version and CHANGELOG diff; merging that PR tags, releases, and triggers the artifact build. `version.txt` and `CHANGELOG.md` are maintained by it — don't hand-edit them outside its PR.

This has one consequence worth internalizing: **a commit with a non-conventional subject is invisible to versioning.** It gets no CHANGELOG entry and triggers no bump. Since upstream's commits are all free-form, the `upstream-sync` PR is titled `feat: sync upstream …` and is meant to be squash-merged so that one classified subject is what lands.

`.release-please-manifest.json` seeds the version line at `1.12.0` — the upstream release this fork forked from — so the breaking mise/Homebrew change computes `2.0.0`. There is no `v1.12.0` *tag*, though: upstream's newest tag is `v1.11.0`, and 1.12.0 exists only as an untagged CHANGELOG entry on its main. `last-release-sha` in [`release-please-config.json`](../release-please-config.json) therefore pins where that notional release sat (`9d8a133`, the last upstream commit before the fork's first), so release-please bounds its scan at the fork boundary instead of walking the entire history. Once `v2.0.0` is tagged, release-please uses that tag and the pin is inert.

See **[`PUBLISHING.md`](../PUBLISHING.md)** for the step-by-step runbook, the conventional-commit reference table, the `TAP_TOKEN` setup, and how to build a release by hand if Actions is unavailable.
