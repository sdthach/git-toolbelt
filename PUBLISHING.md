# Cutting a new release

Runbook for publishing a new version of this fork (`sdthach/git-toolbelt`). See [`docs/maintaining-the-fork.md`](docs/maintaining-the-fork.md) for the surrounding picture (layout, upstream sync, CI/CD).

## Automatic vs. manual

Cutting a release is **semi-automatic**. Pushing a `v*` tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml), which does everything downstream of the tag; you own the version choice, the CHANGELOG, and the tag itself.

| Step | Who |
|---|---|
| Pick the version, update `CHANGELOG.md` | You |
| Create + push the `v*` tag | You |
| Build the release tarball | **Workflow** |
| Attest build provenance | **Workflow** |
| Create the GitHub release with the tarball + `.sha256` attached | **Workflow** |

There are no secrets to configure and no second repo to keep in sync — the release asset *is* the distribution.

## Version numbering

Use plain **`vMAJOR.MINOR.PATCH`**. The fork owns its own version line; it is not tied to upstream's numbering, and `CHANGELOG.md` records which upstream version each release is based on.

`release.yml` **rejects** anything else, because pre-release suffixes break both ends of the toolchain: mise sorts a `-fork.N` tag as a pre-release and excludes it from `latest`, and fuzzy queries like `@1.12` stop resolving predictably. (The `v1.12.0-fork.1` scheme this fork started with is retired; `v2.0.0` is the first release under the new line.)

Fork tags live only in this repo — `upstream` is fetch-only, so a fork tag can never reach `nvie/git-toolbelt`, and upstream's `v1.x` tags stay distinguishable from the fork's own line.

> Commits are currently **unsigned** (a signing/vault fix is pending). Add `--no-gpg-sign` to `git commit`, and tag with `git -c tag.gpgsign=false tag -a …`, until that's resolved.

## Steps

### 1. Check the build locally

```console
$ mise run ci
```

This is exactly what CI runs: shellcheck + yamllint, then a smoke test that builds the release tarball, extracts it, and runs commands off its `bin/`. If it's green here it will be green on the tag.

### 2. Update the CHANGELOG

Edit [`CHANGELOG.md`](CHANGELOG.md): give the release its own header. If there's a working `# Unreleased (fork)` block, rename it to the version; otherwise add a new `# vX.Y.Z` section above the previous one and list the notable changes. Note the upstream base version if it changed.

### 3. Tag and push

```console
$ VER=2.0.0                          # example — set to the new version
$ git switch main && git pull
$ git -c tag.gpgsign=false tag -a "v$VER" -m "git-toolbelt v$VER"
$ git push origin "v$VER"
```

Pushing the tag starts `release.yml`. Watch it:

```console
$ gh run list --repo sdthach/git-toolbelt --workflow release.yml --limit 1
```

It validates the tag shape, builds `git-toolbelt-$VER.tar.gz`, writes the matching `.sha256`, attests provenance, and creates the GitHub release with both files attached.

### 4. Verify the install path

```console
$ gh release view "v$VER" --repo sdthach/git-toolbelt --json assets
$ mise upgrade github:sdthach/git-toolbelt      # or `mise use -g` the first time
$ git main-branch && gatus
```

Both asset names are load-bearing — see [why](docs/maintaining-the-fork.md#how-mise-installs-this). A release with no assets, or with the tarball renamed, is a release mise cannot install.

## Emergency: building the tarball by hand

If Actions is down, the release asset is reproducible locally — the archive is byte-identical for a given commit (sorted entries, pinned uid/gid/mtime, `gzip -n`):

```console
$ VER=2.0.0
$ scripts/build-dist.sh "$VER" dist
$ (cd dist && sha256sum "git-toolbelt-$VER.tar.gz" > "git-toolbelt-$VER.tar.gz.sha256")
$ gh release create "v$VER" --verify-tag --generate-notes dist/*
```

The only thing lost versus the workflow is the provenance attestation.
