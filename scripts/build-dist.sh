#!/bin/sh
#
# Assemble the release tarball that `mise` (and anyone else) installs from.
#
#   usage: scripts/build-dist.sh <version> [outdir]
#   e.g.   scripts/build-dist.sh 2.0.0 dist
#
# The repo keeps the upstream `git-*` scripts at its root (byte-identical to
# nvie/git-toolbelt, so upstream-sync merges stay clean) and the fork's
# shortcuts in portmanteaus/. Neither layout is what we want to ship, so the
# tarball is assembled here instead:
#
#   bin/          <- git-* and portmanteaus/*, flattened into one PATH dir
#   docs/
#   README.md CHANGELOG.md LICENSE
#
# Why `bin/`: mise's github backend, with no `bin_path` tool option set, uses
# <install_path>/bin when that directory exists. Shipping `bin/` at the archive
# root therefore makes `mise use github:sdthach/git-toolbelt` work with zero
# tool options. Two top-level directories plus files also mean mise's
# auto-`strip_components` heuristic (single root dir, no files) cannot fire.
#
# The archive is byte-reproducible for a given commit: entries are sorted, uid/
# gid/mtime are pinned, and gzip is invoked without a timestamp header.
set -eu

version="${1:-}"
outdir="${2:-dist}"

if [ -z "$version" ]; then
    echo "usage: $0 <version> [outdir]" >&2
    exit 2
fi

# Resolve the output directory before moving, so a relative outdir stays
# relative to the caller's cwd rather than to the repo root.
mkdir -p "$outdir"
outdir="$(CDPATH='' cd -- "$outdir" && pwd)"

# Run from the repo root regardless of where we were invoked from.
root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$root"

name="git-toolbelt-${version}"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/bin"
cp -p git-* "$stage/bin/"
cp -p portmanteaus/* "$stage/bin/"
cp -pR docs "$stage/docs"
cp -p README.md CHANGELOG.md LICENSE "$stage/"

# Sanity: every shipped command must be executable and start with a shebang. A
# botched upstream merge that drops the exec bit would otherwise ship silently
# and only fail on the user's machine.
count=0
for f in "$stage"/bin/*; do
    [ -x "$f" ] || { echo "not executable: ${f##*/}" >&2; exit 1; }
    case "$(head -c 2 "$f")" in
        '#!') ;;
        *) echo "no shebang: ${f##*/}" >&2; exit 1 ;;
    esac
    count=$((count + 1))
done
[ "$count" -gt 0 ] || { echo "bin/ is empty" >&2; exit 1; }

# Pin mtimes to the commit date so the same commit always hashes the same.
epoch="$(git log -1 --format=%ct 2>/dev/null || echo 0)"

tar --format=gnu \
    --sort=name \
    --owner=0 --group=0 --numeric-owner \
    --mtime="@$epoch" \
    -C "$stage" -cf - bin docs README.md CHANGELOG.md LICENSE \
    | gzip -9n > "$outdir/$name.tar.gz"

echo "$outdir/$name.tar.gz ($count commands)"
