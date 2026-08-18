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

[ "$fail" -eq 0 ] || exit 1
echo "smoke test passed"
