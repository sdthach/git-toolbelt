# The v2.0.0 distribution rework

Back to the [README](../README.md).

Record of the change that moved this fork from an unusable Homebrew-only release to dual mise/Homebrew distribution with automated versioning, and of the failures found on the way. Most of those failures were **silent** — green checks, successful workflow runs, and documentation that described a state the repo was not in. They are written down here because each one will look fine again the next time it happens.

For how things work now, see [maintaining-the-fork](maintaining-the-fork.md) and [PUBLISHING](../PUBLISHING.md). This document is the *why*.

## The starting problem

`mise use -g github:sdthach/git-toolbelt` could not work:

```
mise ERROR Failed to install github:sdthach/git-toolbelt@latest:
           No matching asset found for platform linux-x64
Available assets:          ← empty
```

mise's github backend installs release **assets**. GitHub's auto-generated "Source code (tar.gz)" is not an asset — it is a separate field in the release API that the backend never looks at. The `v1.12.0-fork.1` release had a tag, notes, and no assets, so there was nothing to install. **A tag is not an installable release.**

## Decisions

### Ship a built tarball, keep the repo layout

The upstream `git-*` scripts stay at the repo root, byte-identical to `nvie/git-toolbelt`, so the weekly upstream merge has nothing to reconcile. The shipped layout is different: [`scripts/build-dist.sh`](../scripts/build-dist.sh) flattens the root scripts and `portmanteaus/` into a single `bin/`.

Moving the scripts into `bin/` in the repo would have been tidier, at the cost of making every upstream merge depend on rename detection. Assembling at release time buys the clean archive without the repo paying for it.

Three properties make the result install with **zero mise tool options**, each verified against mise's `asset_matcher.rs` and `github.rs` rather than assumed:

| Property | Why it matters |
|---|---|
| `bin/` at the archive root | With no `bin_path` set, mise uses `<install_path>/bin` when it exists |
| Two root directories plus files | mise auto-applies `strip_components = 1` only for a single root directory with no files; this shape prevents that |
| Named `git-toolbelt-<version>.tar.gz` | Scores +10 (archive) +20 (repo-name match) = 30; anything scoring ≤ 0 is discarded. No OS/arch token means the one noarch build wins everywhere |

A `.tar.gz.sha256` asset rides along — mise matches that exact name and verifies it, and the `.sha256` extension is penalized in scoring so it can never be selected as the tool itself.

### Both package managers, one artifact

Homebrew was kept rather than replaced, with the formula's `url` pointed at the same release asset. `def install` is `bin.install Dir["bin/*"]`, with a fallback to the repo layout for `--HEAD` builds. One tarball and one checksum serve both paths, so a bug in one is a bug in both.

The tap copy is now replaced **wholesale** from `packaging/git-toolbelt.rb` on each release, with only `url`/`sha256` rewritten. The previous patch-in-place approach let the tap accumulate two commits — a test-block fix and a version pin — that never made it back here.

### Plain `vX.Y.Z`, fork-owned

The `-fork.N` suffix broke both ends: mise sorts it as a pre-release and excludes it from `latest`, and Homebrew parsed it down to a bare `1`, which required an explicit `version` pin in the formula to work around. The fork now owns its own version line starting at `2.0.0`, and the pin is gone.

### Versions computed, not chosen

[release-please](https://github.com/googleapis/release-please) reads conventional-commit subjects on `main` and keeps a `chore: release X.Y.Z` PR open. Merging it tags, releases, and triggers the artifact build in the same workflow run — deliberately one workflow, because **a tag pushed by `GITHUB_TOKEN` does not trigger other workflows**, so a separate tag-triggered job would never fire without a PAT.

Consequence worth internalizing: a commit whose subject is not conventional is invisible to versioning — no changelog entry, no bump. Upstream's commits are all free-form, which is why the sync PR is titled `feat: sync upstream …` and is meant to be squash-merged.

## What was silently broken

### `gh` resolves a fork's base repo to its parent

`gh pr create` inside this fork targets `nvie/git-toolbelt`, failing with the misleading *"No commits between main and \<branch\>"* — the branch has plenty of commits, just none in common with upstream's `main`.

`upstream-sync.yml` contained exactly that call. It had **six consecutive successful runs**, all 6–16 seconds long, because upstream's tip had been an ancestor of `main` the whole time and every run hit the "nothing to sync" early exit. The `gh pr create` line had never executed. The green checkmarks were testing nothing, and the first real upstream change would have broken the weekly sync quietly.

Every workflow step shelling out to `gh` now sets `GH_REPO: ${{ github.repository }}`. Locally, `gh repo set-default` does the same job — `mise run setup` does it for you.

### A required status check that no longer reports

Branch protection required a check named `shellcheck`, the job name in the `lint.yml` this work replaced. A required check that never reports is never satisfied, so the PR sat `BLOCKED` with every check green — and every future PR would have too, including release-please's.

CI is now split into `shellcheck` / `yamllint` / `smoke` jobs, which restores the required name and makes failures self-identifying. **These job names are load-bearing**; update the protection rule before renaming them.

### Actions could not open pull requests

release-please parsed the commits, created its branch, and committed the changelog, then failed:

```
##[error] release-please failed: GitHub Actions is not permitted to
          create or approve pull requests.
```

Repo setting, off by default. The same setting had also been disabling `upstream-sync.yml`'s PR creation.

### Workflows on bot-authored PRs need approval

The release PR's CI run sat at `action_required` with a 0-second duration. No check would ever have reported, so the PR was unmergeable for a reason invisible in the checks list.

### Documentation describing a state that did not exist

Two cases, both live for months:

- `maintaining-the-fork.md` said `upstream` was *"fetch-only, push disabled"*. The push URL was live; `git push upstream main` would have reached the original author's repo. It is now `DISABLED`, set by `mise run setup`.
- `PUBLISHING.md` said commits were unsigned and to pass `--no-gpg-sign`, while the `main_protection` ruleset required **verified signatures**. Following the runbook produced commits that could not be merged.

Both settings live in `.git/config`, which is untracked and cannot travel with a clone. That is why they rot, and why they are now a task ([`scripts/dev-setup.sh`](../scripts/dev-setup.sh)) rather than a paragraph. A command can be run and verified; a paragraph can only be believed.

### Signatures that would not verify

Chasing the signing requirement produced two dead ends worth recording, because both look identical from the outside — `verified=false, reason=unknown_key`, with no hint which applies:

1. **Authentication keys and signing keys are separate registrations.** The key that pushes fine can leave every commit `Unverified`. It must be added a second time with `--type signing`.
2. **The commit email decides which account is checked.** GitHub attributes a commit to the account owning its committer email, then looks for signing keys *on that account*. Commits carried an email belonging to a second, older account, while the keys were registered on the account that owns this repo. Matching fingerprints, correct key type, and registration predating the commits made no difference.

The second was the real cause; the first was a genuine problem found on the way. One call distinguishes them:

```console
$ gh api repos/sdthach/git-toolbelt/commits/<sha> \
    --jq '"\(.author.login)  \(.commit.verification.reason)"'
sdthach  valid
```

If that login is not the account holding your keys, the email is the problem, not the key.

## Verification

The install path was tested against the real published release, not a local mock:

```console
$ cat mise.toml
[tools]
"github:sdthach/git-toolbelt" = "2.0.0"     # no tool options

$ mise install
✓ GitHub artifact attestations verified
✓ installed

77 commands on PATH
git main-branch -> main      git toolbelt --version -> 2.0.0
```

CI asserts the shape on every push: [`scripts/smoke-test.sh`](../scripts/smoke-test.sh) builds the tarball, extracts it, checks for the top-level `bin/`, runs commands off it, confirms the stamped version round-trips, and fails if any shipped command has lost its exec bit or shebang.

## Still open

- **`require_code_owner_review: true` with no `CODEOWNERS` file.** The requirement cannot be satisfied as configured, so every PR needs an admin bypass. Unchecking it in the `main_protection` ruleset is the fix.
- **Commit attribution splits at the v2 work.** Earlier commits belong to the older account; later ones to the account that owns the repo. Harmless, but it explains a discontinuity in `git log`.
- **The 2.0.0 changelog links to a `v1.12.0` tag that does not exist** — upstream's newest tag is `v1.11.0`, and 1.12.0 exists only as an untagged CHANGELOG entry. Cosmetic; self-corrects from the next release.
