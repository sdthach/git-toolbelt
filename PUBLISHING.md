# Cutting a new release

Runbook for publishing a new version of this fork (`sdthach/git-toolbelt`) and its Homebrew tap (`sdthach/homebrew-tap`). See [`docs/maintaining-the-fork.md`](docs/maintaining-the-fork.md) for the surrounding picture (layout, upstream sync, CI/CD).

## The short version

**Merge the release PR.** That's the whole release.

[release-please](https://github.com/googleapis/release-please) watches `main`, reads the conventional-commit subjects landed since the last release, and keeps a single **`chore: release X.Y.Z`** PR open showing the version it computed and the `CHANGELOG.md` diff that goes with it. That PR is a live preview — it re-opens or updates itself on every push to `main`. Merging it tags, releases, and publishes:

| Step | Who |
|---|---|
| Write conventional commit subjects | You |
| Compute the next version | **release-please** |
| Draft `CHANGELOG.md` + the release PR | **release-please** |
| Decide *when* to release (by merging that PR) | You |
| Tag + create the GitHub release | **release-please** |
| Build the tarball + `.sha256`, attest provenance, attach | **Workflow** |
| Bump the tap formula | **Workflow** — *only if `TAP_TOKEN` is set* (see below) |

## Conventional commits

The version comes from commit subjects, so subjects are now load-bearing:

| Subject | Effect |
|---|---|
| `fix: …` | patch — `2.0.0` → `2.0.1` |
| `feat: …` | minor — `2.0.0` → `2.1.0` |
| `feat!: …` or a `BREAKING CHANGE:` footer | major — `2.0.0` → `3.0.0` |
| `docs:` `build:` `refactor:` `perf:` | listed in the CHANGELOG, no bump on their own |
| `ci:` `test:` `chore:` | hidden from the CHANGELOG, no bump |

Anything that doesn't parse as a conventional subject is ignored entirely — no CHANGELOG entry, no bump. That's the failure mode to watch for: land only unclassified commits and release-please will not open a PR at all. The types and their CHANGELOG sections are configured in [`release-please-config.json`](release-please-config.json).

### Upstream syncs

Upstream's own commit subjects are free-form and can't be classified. The `upstream-sync` workflow therefore titles its PR `feat: sync upstream nvie/git-toolbelt (N commits)` — **squash-merge it** so that single subject is what lands on `main`. Retitle it to `fix:` if the sync is fixes only.

## Version numbering

Plain **`vMAJOR.MINOR.PATCH`**. The fork owns its own version line; it is not tied to upstream's numbering, and `CHANGELOG.md` records what each release contains.

The old `vX.Y.Z-fork.N` scheme is retired. It broke both distribution paths: mise sorts a `-fork.N` tag as a pre-release and excludes it from `latest`, and Homebrew mis-parsed it down to a bare `1`, which needed an explicit `version` pin in the formula to work around. `v2.0.0` is the first release under the new line, and the version pin is gone.

Fork tags live only in this repo — `upstream` is fetch-only, so a fork tag can never reach `nvie/git-toolbelt`.

> Commits are currently **unsigned** (a signing/vault fix is pending). Add `--no-gpg-sign` to `git commit` until that's resolved.

## Steps

### 1. Land your work with conventional subjects

```console
$ mise run ci        # same checks CI runs: lint + tarball smoke test
$ git commit -m "fix: git-workon no longer races the fetch"
```

Open a PR as usual. If you squash-merge, **the squash subject is what release-please reads** — GitHub defaults it to the PR title, so the PR title needs to be conventional too.

### 2. Review the release PR

release-please opens or updates `chore: release X.Y.Z` within a minute of the merge. Check that the computed version matches your intent (a missing `!` is the usual cause of a minor where you wanted a major) and that the CHANGELOG reads well. Edit the CHANGELOG in the PR if you want to reword it — release-please preserves manual edits to its PR.

### 3. Merge it

Merging tags `vX.Y.Z`, creates the GitHub release with the generated notes, and — in the same workflow run — builds `git-toolbelt-X.Y.Z.tar.gz`, writes its `.sha256`, attests build provenance, attaches both, and pushes the new `url`/`sha256` into the tap formula.

Doing both halves in one run is deliberate: a tag pushed by `GITHUB_TOKEN` does not trigger other workflows, so a separate tag-triggered job would never fire without a PAT.

```console
$ gh run list --repo sdthach/git-toolbelt --workflow release.yml --limit 1
```

### 4. Verify both install paths

```console
$ gh release view "v$VER" --repo sdthach/git-toolbelt --json assets

$ mise upgrade github:sdthach/git-toolbelt
$ brew update && brew upgrade sdthach/tap/git-toolbelt
$ brew test git-toolbelt

$ git main-branch && gatus
```

Both asset names are load-bearing for mise — see [why](docs/maintaining-the-fork.md#how-the-two-install-paths-work). A release with no assets, or with the tarball renamed, is a release mise cannot install.

## One-time: enable the tap bump

The tap bump pushes to a *different* repo (`sdthach/homebrew-tap`), which the default `GITHUB_TOKEN` can't do. Create a **fine-grained PAT** with **contents: write** scoped to `sdthach/homebrew-tap`, then:

```console
$ gh secret set TAP_TOKEN --repo sdthach/git-toolbelt
```

Until it's set, that step is **skipped gracefully** — the release and its assets still publish, so the mise path stays live, and a `::notice::` reminds you to bump the tap by hand:

```console
$ VER=2.0.0
$ URL="https://github.com/sdthach/git-toolbelt/releases/download/v$VER/git-toolbelt-$VER.tar.gz"
$ SHA="$(curl -fsSL "$URL" | sha256sum | cut -d' ' -f1)"
$ git clone https://github.com/sdthach/homebrew-tap.git && cd homebrew-tap
$ cp ../git-toolbelt/packaging/git-toolbelt.rb git-toolbelt.rb
$ sed -i -E -e "s|^(\s*)url \".*\"|\1url \"$URL\"|" \
            -e "s|^(\s*)sha256 \".*\"|\1sha256 \"$SHA\"|" git-toolbelt.rb
$ git commit -am "git-toolbelt v$VER" && git push
```

Note this copies `packaging/git-toolbelt.rb` over the tap file wholesale, which is what the workflow does too — so formula edits (dependencies, the `test do` block) reach the tap instead of having to be re-applied there by hand.

## Emergency: building the tarball without Actions

The release asset is reproducible locally — the archive is byte-identical for a given commit (sorted entries, pinned uid/gid/mtime, `gzip -n`):

```console
$ VER=2.0.0
$ scripts/build-dist.sh "$VER" dist
$ (cd dist && sha256sum "git-toolbelt-$VER.tar.gz" > "git-toolbelt-$VER.tar.gz.sha256")
$ gh release create "v$VER" --verify-tag --generate-notes dist/*
```

The only thing lost versus the workflow is the provenance attestation.
