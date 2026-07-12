# Cutting a new release

Runbook for publishing a new version of this fork (`sdthach/git-toolbelt`) and its Homebrew tap (`sdthach/homebrew-tap`). See [`docs/maintaining-the-fork.md`](docs/maintaining-the-fork.md) for the surrounding picture (install modes, upstream sync, CI/CD).

## Automatic vs. manual

Cutting a release is **semi-automatic**. Pushing a `v*` tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml), which does the GitHub-release side for you; you own the version choice, the CHANGELOG, and the tag itself.

| Step | Who |
|---|---|
| Pick the version, update `CHANGELOG.md` | You |
| Create + push the `v*` tag | You |
| Create the GitHub release (notes auto-generated) | **Workflow** |
| Hash the tarball, bump the tap formula's `url`/`sha256`/`version` | **Workflow** — *only if `TAP_TOKEN` is set* (see below); otherwise **you**, by hand |

Until `TAP_TOKEN` is configured, the workflow **skips the tap bump gracefully** (it still creates the GitHub release and emits a `::notice::`), and you do the [manual tap bump](#3-bump-the-tap-formula) yourself.

## Version numbering

Use **`vMAJOR.MINOR.PATCH-fork.N`**, where `MAJOR.MINOR.PATCH` is the upstream (`nvie/git-toolbelt`) version this release is based on, and `N` is the fork-only build counter on top of that base.

- First fork release off upstream `v1.12.0` → `v1.12.0-fork.1`; the next fork-only release → `v1.12.0-fork.2`, and so on.
- When you merge a newer upstream (e.g. upstream cuts `v1.13.0` and you sync it in), re-base the number: the next fork release becomes `v1.13.0-fork.1`.

**Why the `-fork.N` suffix** (not a plain `v1.12.1`): fork tags live only in this repo and never reach upstream (the `upstream` remote is fetch-only). The suffix keeps fork tags out of upstream's tag namespace, so a future `git fetch upstream` can't collide with a same-named upstream tag, and the version never *implies* it's an upstream release.

**Brew mis-parse gotcha (already handled):** Homebrew parses a `-fork.N` tag down to a bare number, which breaks `brew upgrade` detection. The formula therefore pins `version` explicitly, and `release.yml` rewrites that `version` line alongside `url`/`sha256` on each release. You don't need to do anything extra — just keep the `version "…"` line present in the tap formula.

> Commits are currently **unsigned** (a signing/vault fix is pending). Add `--no-gpg-sign` to `git commit`, and tag with `git -c tag.gpgsign=false tag -a …`, until that's resolved.

## Steps

### 1. Update the CHANGELOG

Edit [`CHANGELOG.md`](CHANGELOG.md): give the release its own header. If there's a working `# Unreleased (fork)` block, rename it to the version; otherwise add a new `# vX.Y.Z-fork.N` section above the previous one and list the notable changes.

### 2. Tag and push

```console
$ VER=1.12.0-fork.2                 # example — set to the new version
$ git switch main && git pull
$ git -c tag.gpgsign=false tag -a "v$VER" -m "git-toolbelt v$VER"
$ git push origin "v$VER"
```

Pushing the tag starts `release.yml`. Watch it:

```console
$ gh run list --repo sdthach/git-toolbelt --workflow release.yml --limit 1
```

It creates the GitHub release from the tag with auto-generated notes. If `TAP_TOKEN` is set, it also bumps the tap formula and you can skip to [step 4](#4-verify). If not, the "Update homebrew-tap formula" step shows as **skipped** — do step 3.

### 3. Bump the tap formula

Only needed while `TAP_TOKEN` is unset. This mirrors exactly what the workflow would do.

```console
$ VER=1.12.0-fork.2
$ URL="https://github.com/sdthach/git-toolbelt/archive/refs/tags/v${VER}.tar.gz"
$ SHA="$(curl -fsSL "$URL" | sha256sum | cut -d' ' -f1)"
$ git clone https://github.com/sdthach/homebrew-tap.git
$ cd homebrew-tap
$ sed -i -E \
    -e "s|^(\s*)url \".*\"|\1url \"$URL\"|" \
    -e "s|^(\s*)sha256 \".*\"|\1sha256 \"$SHA\"|" \
    -e "s|^(\s*)version \".*\"|\1version \"$VER\"|" \
    git-toolbelt.rb
$ git commit -am "git-toolbelt v$VER"
$ git push
```

### 4. Verify

```console
$ brew update
$ brew upgrade sdthach/tap/git-toolbelt     # or: brew install sdthach/tap/git-toolbelt
$ brew list --versions git-toolbelt          # should show the new version
$ brew test git-toolbelt                      # exercises git-main-branch
```

## One-time: enable full automation

To make step 3 automatic on every release, create a **fine-grained PAT** with **contents: write** scoped to `sdthach/homebrew-tap`, then:

```console
$ gh secret set TAP_TOKEN --repo sdthach/git-toolbelt
```

After that, pushing a `v*` tag bumps the tap formula on its own — steps 1, 2, and 4 are all you do. See the `TAP_TOKEN` section in [`docs/maintaining-the-fork.md`](docs/maintaining-the-fork.md).
