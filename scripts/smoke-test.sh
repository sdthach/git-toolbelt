#!/bin/sh
#
# Build the release tarball and exercise it the way an install does: extract it,
# put its bin/ on PATH, and run a few commands against a throwaway repo.
#
# This guards the two things that silently break a release — the archive not
# having a top-level bin/ (which is what makes mise's zero-config binary
# discovery work), and a command losing its exec bit or shebang in a merge.
set -eu

root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

version="0.0.0-smoke"
"$root/scripts/build-dist.sh" "$version" "$tmp" >/dev/null

mkdir -p "$tmp/extracted"
tar xzf "$tmp/git-toolbelt-$version.tar.gz" -C "$tmp/extracted"

# mise's github backend uses <install_path>/bin when it exists, with no
# bin_path tool option needed. Losing this directory would silently move the
# burden onto every user's config.
if [ ! -d "$tmp/extracted/bin" ]; then
    echo "FAIL: archive has no top-level bin/ directory" >&2
    exit 1
fi

PATH="$tmp/extracted/bin:$PATH"
export PATH

# A real repo to exercise the commands against.
repo="$tmp/repo"
git init -q -b main "$repo"
git -C "$repo" -c user.name=smoke -c user.email=smoke@example.com \
    commit -q --allow-empty -m "initial"

fail=0
check() {
    label="$1"
    expected="$2"
    shift 2
    actual="$("$@" 2>&1)" || {
        echo "FAIL: $label exited non-zero: $actual" >&2
        fail=1
        return
    }
    if [ "$actual" != "$expected" ]; then
        echo "FAIL: $label = '$actual', expected '$expected'" >&2
        fail=1
        return
    fi
    echo "ok: $label = $expected"
}

# Resolved as `git <verb>` subcommands, which is the whole point of the layout.
check "git main-branch" "main" git -C "$repo" main-branch
check "git current-branch" "main" git -C "$repo" current-branch
check "git is-repo" "" git -C "$repo" is-repo

# The identity command must report the version it was built with, not "dev" —
# a failed stamp would ship a release that cannot say which release it is.
check "git toolbelt --version" "$version" git toolbelt --version

# A portmanteau shortcut is a standalone command, not a git subcommand.
if ! command -v gatus >/dev/null; then
    echo "FAIL: portmanteau 'gatus' not on PATH" >&2
    fail=1
else
    echo "ok: portmanteau gatus on PATH"
fi

# Every shipped command should at least be a runnable file.
missing="$(find "$tmp/extracted/bin" -maxdepth 1 -type f ! -perm -u+x | wc -l)"
if [ "$missing" -ne 0 ]; then
    echo "FAIL: $missing shipped command(s) are not executable" >&2
    fail=1
else
    echo "ok: all $(find "$tmp/extracted/bin" -maxdepth 1 -type f | wc -l) commands executable"
fi

# The bare-worktree commands are flattened into bin/ with everything else, and
# resolve as git subcommands from there.
bin="$tmp/extracted/bin"
for cmd in git-clone-worktree git-init-worktree git-convert-worktree \
    git-switch-worktree git-bare-worktree git-bwt; do
    if [ "$(command -v "$cmd")" != "$bin/$cmd" ]; then
        echo "FAIL: $cmd does not resolve from the extracted bin/" >&2
        fail=1
    else
        echo "ok: $cmd on PATH"
    fi
done

# The sample printer needs no Worktrunk and no repo, so it must work off a bare
# install.
if out="$(git bwt config-example 2>&1)" && [ -n "$out" ]; then
    echo "ok: git bwt config-example"
else
    echo "FAIL: git bwt config-example: $out" >&2
    fail=1
fi

# bare-worktree/ also holds docs and samples; only its git-* commands may land
# in bin/. The never-released wt-* names must not come back either.
stray="$(find "$bin" -maxdepth 1 \( -name 'wt-*' -o -name 'README.md' \
    -o -name '*.example' \) | wc -l)"
if [ "$stray" -ne 0 ]; then
    echo "FAIL: $stray non-command file(s) in bin/" >&2
    fail=1
else
    echo "ok: no wt-*, README.md or *.example in bin/"
fi

# The bare-worktree docs and config samples ship under share/, without the
# repo-only docs/plans/.
share="$tmp/extracted/share/git-toolbelt/bare-worktree"
for f in README.md config.toml.example wt.toml.example \
    docs/getting-started.md docs/usage.md docs/architecture.md \
    docs/decisions.md docs/gotchas.md; do
    if [ ! -f "$share/$f" ]; then
        echo "FAIL: share/git-toolbelt/bare-worktree/$f missing" >&2
        fail=1
    else
        echo "ok: share/git-toolbelt/bare-worktree/$f"
    fi
done
if [ -n "$(find "$tmp/extracted/share" -name plans)" ]; then
    echo "FAIL: docs/plans/ shipped under share/" >&2
    fail=1
else
    echo "ok: no plans/ under share/"
fi

[ "$fail" -eq 0 ] || exit 1
"$root/scripts/test-bare-worktree.sh"
echo "smoke test passed"
