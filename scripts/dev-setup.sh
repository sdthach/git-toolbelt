#!/bin/sh
#
# One-time developer setup for a clone of this repo. Idempotent — safe to re-run,
# and safe to run on a clone that is already configured.
#
# These settings live in .git/config, which is not tracked, so they do not
# survive a fresh clone and cannot be carried by the repo itself. Keeping them
# as a task rather than as prose in the docs is what stops them being forgotten:
# the `upstream` push URL was documented as disabled long before it actually was.
set -eu

UPSTREAM_URL="https://github.com/nvie/git-toolbelt.git"
FORK="sdthach/git-toolbelt"

root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$root"

# 1. `upstream` points at the original project, for syncing fixes and features.
if git remote get-url upstream >/dev/null 2>&1; then
    git remote set-url upstream "$UPSTREAM_URL"
else
    git remote add upstream "$UPSTREAM_URL"
fi

# 2. ...but pushing to it is disabled, so a stray `git push upstream` can't reach
#    the original author's repo. Fetch keeps working; only push is severed.
git remote set-url --push upstream DISABLED
echo "ok: upstream -> $UPSTREAM_URL (push disabled)"

# 3. main requires a verified signature on every commit (the main_protection
#    ruleset), so an unsigned commit blocks its own PR no matter how green CI is.
#    The key itself is personal and machine-specific, so it is never hardcoded
#    here — this only switches signing on once you have one configured.
if key="$(git config --get user.signingkey)" && [ -n "$key" ]; then
    git config commit.gpgsign true
    git config tag.gpgsign true
    echo "ok: commit signing enabled (key: $key)"
else
    echo "warn: no signing key configured, but main requires verified signatures." >&2
    echo "      SSH:  git config --global gpg.format ssh" >&2
    echo "            git config --global user.signingkey ~/.ssh/<key>.pub" >&2
    echo "            gh ssh-key add ~/.ssh/<key>.pub --type signing" >&2
    echo "      GPG:  git config --global user.signingkey <key-id>" >&2
    echo "            gpg --armor --export <key-id> | gh gpg-key add -" >&2
fi

# 4. gh resolves a fork's base repo to its PARENT, so an unqualified
#    `gh pr create` here targets nvie/git-toolbelt and fails. Pin it to the fork.
if command -v gh >/dev/null 2>&1; then
    if gh repo set-default "$FORK" >/dev/null 2>&1; then
        echo "ok: gh default repo -> $FORK"
    else
        echo "warn: could not set the gh default repo; run 'gh auth login' first" >&2
    fi
else
    echo "note: gh not installed — skipped pinning the default repo" >&2
fi
