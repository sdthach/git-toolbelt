#!/bin/sh
#
# Tests for git-modified.
#
# The git-modified under test, with the git-relative-path and git-root it
# calls, is the checkout's own, or the one in $TOOLBELT_TEST_BIN (the release
# smoke test points that at the extracted bin/). Whatever else is on PATH,
# such as an installed git-toolbelt, is not used.
#
# Three groups of checks, each run under every available POSIX shell (dash,
# bash --posix, busybox sh; TOOLBELT_TEST_SHELLS="dash bash" narrows it):
#
#   1. Differential: for ordinary filenames the output, stderr and exit status
#      must be byte-identical to git-modified as of upstream 354262e, the
#      version before the quoting fix, for every flag, commit and pathspec
#      combination below. The one intended difference, `-u` listing add/add
#      (AA) conflicts, is asserted on its own. The reference is that file's
#      blob, which the fork's main has had since the 354262e sync (20a60d9),
#      so a shallow clone cannot run this test.
#   2. Filenames git quotes or splits on, and names the dash `echo` mangles,
#      in every mode and as rename source and destination.
#   3. Names with a newline: skipped with one warning each, and the entries
#      after them are still right.
#
# Run it with a private umask, e.g. (umask 077; scripts/test-git-modified.sh).
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# git-modified as of upstream 354262e.
reference=618ca8b28cd223dd5934e314c1e3107f2c0dc40b

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tmp=$(CDPATH='' cd -P -- "$tmp" && pwd -P)

die() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

passes=0
failures=0
ok() {
    passes=$((passes + 1))
}
bad() {
    failures=$((failures + 1))
    printf 'FAIL: %s\n' "$*" >&2
}
# section_done <summary>: prints the summary when the section had no failures.
section_failures=0
section_done() {
    if [ "$failures" -eq "$section_failures" ]; then
        printf 'ok: %s\n' "$1"
    fi
    section_failures=$failures
}

# --- The commands under test and the reference --------------------------------

bin=${TOOLBELT_TEST_BIN:-$root}
bin=$(CDPATH='' cd -- "$bin" && pwd) || die "no directory $TOOLBELT_TEST_BIN"
for cmd in git-modified git-relative-path git-root; do
    [ -x "$bin/$cmd" ] || die "no executable $cmd in $bin"
done

mkdir "$tmp/new" "$tmp/old" "$tmp/sys" "$tmp/home"
cp "$bin/git-modified" "$tmp/new/git-modified"
if ! git -C "$root" cat-file -e "$reference" 2>/dev/null; then
    die "the reference git-modified (blob $reference) is not in this clone; a shallow clone needs 'git fetch --unshallow' (CI: fetch-depth: 0)"
fi
git -C "$root" cat-file blob "$reference" > "$tmp/old/git-modified"
for helper in git-relative-path git-root; do
    ln -s "$bin/$helper" "$tmp/new/$helper"
    ln -s "$bin/$helper" "$tmp/old/$helper"
done
chmod 755 "$tmp/new/git-modified" "$tmp/old/git-modified"

# A controlled PATH: only the tools the scripts and this test use, so nothing
# else on the machine (zoxide, a different git-modified) can leak in.
for tool in sh git tr realpath which head grep sed cut cat mkdir rm mv cp ln \
    seq sort cmp diff printf env dirname; do
    path=$(command -v "$tool") || die "$tool is not on PATH"
    case $path in /*) ;; *) continue ;; esac
    ln -s "$path" "$tmp/sys/$tool"
done

shells=
for s in ${TOOLBELT_TEST_SHELLS:-dash bash busybox}; do
    case $s in
        dash|bash) command -v "$s" >/dev/null 2>&1 && shells="$shells $s" ;;
        busybox) busybox sh -c : 2>/dev/null && shells="$shells $s" ;;
        *) die "unknown shell in TOOLBELT_TEST_SHELLS: $s" ;;
    esac
done
[ -n "$shells" ] || die "none of the shells to test with is installed"
dash_bin=$(command -v dash 2>/dev/null || true)
bash_bin=$(command -v bash 2>/dev/null || true)
busybox_bin=$(command -v busybox 2>/dev/null || true)

# shellcheck disable=SC2123 # replacing the search path is the point
PATH=$tmp/sys
export PATH

# --- An isolated environment ---------------------------------------------------

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_CONFIG_PARAMETERS GIT_CONFIG_GLOBAL \
    GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL EMAIL \
    GIT_CONFIG_COUNT
HOME=$tmp/home
XDG_CONFIG_HOME=$tmp/home/.config
GIT_CONFIG_NOSYSTEM=1
GIT_CEILING_DIRECTORIES=$tmp
GIT_PAGER='cat'
# A UTF-8 locale where there is one, so bash matches patterns by character.
unset LC_ALL LC_CTYPE LC_COLLATE LANGUAGE
LANG=C.UTF-8
export HOME XDG_CONFIG_HOME GIT_CONFIG_NOSYSTEM GIT_CEILING_DIRECTORIES \
    GIT_PAGER LANG
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main

nl='
'

# gm <old|new> <shell> <dir> [args...]: runs that git-modified from <dir>,
# stdout to $tmp/<old|new>.out, stderr to .err, exit status in $status.
gm() {
    which=$1 shell=$2 dir=$3
    shift 3
    set +e
    (
        cd "$dir" || exit 99
        # git finds `git relative-path` and `git root` on PATH.
        PATH=$tmp/$which:$PATH
        script=$tmp/$which/git-modified
        case $shell in
            dash) exec "$dash_bin" "$script" "$@" ;;
            bash) exec "$bash_bin" --posix "$script" "$@" ;;
            busybox) exec "$busybox_bin" sh "$script" "$@" ;;
        esac
    ) < /dev/null > "$tmp/$which.out" 2> "$tmp/$which.err"
    status=$?
    set -e
}

# --- Fixtures -----------------------------------------------------------------

commit() {
    git -C "$1" add -A
    git -C "$1" commit -q -m "$2"
}

# Distinct content that rename and copy detection can match.
lines() {
    seq "$1" "$(($1 + 40))"
}

# unmerge <repo> <stages> <path>: puts <path> in the index as a conflict with
# the given stages (1 base, 2 ours, 3 theirs), e.g. "23" for add/add. The
# mode-0 entry first removes any stage-0 entry for the path.
unmerge() {
    {
        printf '0 %s\t%s\0' 0000000000000000000000000000000000000000 "$3"
        for stage in $(printf '%s\n' "$2" | sed -e 's/./& /g'); do
            blob=$(printf 'stage %s\n' "$stage" | git -C "$1" hash-object -w --stdin)
            printf '100644 %s %s\t%s\0' "$blob" "$stage" "$3"
        done
    } | git -C "$1" update-index -z --index-info
}

# Ordinary names in every state git status reports, with a subdirectory.
ord=$tmp/ord
git init -q "$ord"
mkdir -p "$ord/sub/deep"
for f in a b c d e f g h i; do echo "$f" > "$ord/$f.txt"; done
echo s1 > "$ord/sub/s1.txt"
echo s2 > "$ord/sub/s2.txt"
echo s3 > "$ord/sub/deep/s3.txt"
lines 100 > "$ord/ren1.txt"
lines 200 > "$ord/ren2.txt"
lines 300 > "$ord/ren3.txt"
lines 400 > "$ord/wtren.txt"
lines 500 > "$ord/cp-src.txt"
lines 600 > "$ord/sub/ren4.txt"
echo '*.log' > "$ord/.gitignore"
commit "$ord" first
echo a2 >> "$ord/a.txt"
echo s1b >> "$ord/sub/s1.txt"
git -C "$ord" rm -q e.txt
git -C "$ord" mv ren3.txt sub/ren3-moved.txt
echo gone > "$ord/gone.txt"
echo new-in-second > "$ord/sub/second.txt"
commit "$ord" second
echo a3 >> "$ord/a.txt"
git -C "$ord" mv sub/ren4.txt ren4-back.txt
lines 700 > "$ord/rd-src.txt"
commit "$ord" third
# The work tree and index on top of that:
echo a4 >> "$ord/a.txt"                                     # ' M'
echo b2 >> "$ord/b.txt"; git -C "$ord" add b.txt            # 'M '
echo s2b >> "$ord/sub/s2.txt"; git -C "$ord" add sub/s2.txt
echo s2c >> "$ord/sub/s2.txt"                               # 'MM'
echo n > "$ord/new-staged.txt"; git -C "$ord" add new-staged.txt   # 'A '
echo n > "$ord/sub/new-am.txt"; git -C "$ord" add sub/new-am.txt
echo n2 >> "$ord/sub/new-am.txt"                            # 'AM'
echo n > "$ord/new-ad.txt"; git -C "$ord" add new-ad.txt
rm "$ord/new-ad.txt"                                        # 'AD'
git -C "$ord" rm -q f.txt                                   # 'D '
rm "$ord/g.txt"                                             # ' D'
rm "$ord/gone.txt"                                          # ' D', in HEAD~1
echo h2 >> "$ord/h.txt"; git -C "$ord" add h.txt
rm "$ord/h.txt"                                             # 'MD'
git -C "$ord" mv ren1.txt ren1-new.txt                      # 'R '
git -C "$ord" mv ren2.txt sub/ren2-new.txt
echo more >> "$ord/sub/ren2-new.txt"                        # 'RM'
mv "$ord/wtren.txt" "$ord/wtren-new.txt"
git -C "$ord" add -N wtren-new.txt                          # ' R'
cp "$ord/cp-src.txt" "$ord/cp-dst.txt"
echo more >> "$ord/cp-src.txt"
git -C "$ord" add cp-src.txt cp-dst.txt                     # 'C ' with copies
git -C "$ord" mv rd-src.txt rd-dst.txt; rm "$ord/rd-dst.txt"   # 'RD'
echo u > "$ord/untracked.txt"                               # '??'
echo u > "$ord/sub/untracked-sub.txt"
mkdir "$ord/untracked-dir"; echo u > "$ord/untracked-dir/x.txt"
echo ignored > "$ord/debug.log"                             # ignored

# Every unmerged state except add/add, next to an ordinary change.
unm=$tmp/unm
git init -q "$unm"
mkdir "$unm/sub"
echo k > "$unm/keep.txt"
echo s > "$unm/sub/s.txt"
commit "$unm" first
echo k2 >> "$unm/keep.txt"
for spec in 123:uu 2:au 3:ua 13:du 12:ud 1:dd 123:sub/uu2; do
    unmerge "$unm" "${spec%%:*}" "${spec#*:}.txt"
done
for f in uu au ua du ud sub/uu2; do echo worktree > "$unm/$f.txt"; done

# An add/add conflict, the one state the old -u missed.
aa=$tmp/aa
git init -q "$aa"
mkdir "$aa/sub"
echo k > "$aa/keep.txt"
echo s > "$aa/sub/s.txt"
commit "$aa" first
echo k2 >> "$aa/keep.txt"
unmerge "$aa" 23 both-added.txt
unmerge "$aa" 123 both-modified.txt
echo w > "$aa/both-added.txt"
echo w > "$aa/both-modified.txt"

# A repository without commits.
unborn=$tmp/unborn
git init -q "$unborn"
mkdir "$unborn/sub"
echo u > "$unborn/untracked.txt"
echo s > "$unborn/sub/staged.txt"
echo s > "$unborn/staged-am.txt"
git -C "$unborn" add sub/staged.txt staged-am.txt
echo s2 >> "$unborn/staged-am.txt"

mkdir "$tmp/norepo"

# --- 1. Differential against the reference ---------------------------------------

# One invocation per line; "-" stands for no arguments. Globs stay literal.
worktree_specs='-
-m
-i
-u
-q
-mq
-iq
-uq
-mi
-mu
-iu
-miu
-m -i
-q -u
-- .
-- sub
-- sub/deep
-m -- sub
-i -- sub
-i -- .
-u -- .
-- *.txt
-i -- :(glob)**/*.txt
-- nonexistent
-i -- nonexistent
-x
-mx
-h
-qh
-- -h'
commit_specs='HEAD
HEAD~1
HEAD~2
HEAD~3
-q HEAD
-q HEAD~2
HEAD -q
HEAD -- sub
HEAD~2 -- .
HEAD~1 -- nonexistent
HEAD -m
-i HEAD
HEAD -u
HEAD~1 HEAD
nosuchref
a.txt
sub'

compared=0
nonempty=0
# differ <label> <shells> <dir> <specs>: every spec from <dir>, the new script
# under each shell against the reference under dash.
differ() {
    label=$1 in_shells=$2 dir=$3 specs=$4
    saved_ifs=$IFS
    IFS=$nl
    set -f
    for spec in $specs; do
        IFS=$saved_ifs
        # Split on spaces on purpose; set -f keeps the globs literal.
        # shellcheck disable=SC2086
        if [ "$spec" = - ]; then set --; else set -- $spec; fi
        gm old dash "$dir" "$@"
        cp "$tmp/old.out" "$tmp/ref.out"
        cp "$tmp/old.err" "$tmp/ref.err"
        ref_status=$status
        [ -s "$tmp/ref.out" ] && nonempty=$((nonempty + 1))
        for shell in $in_shells; do
            gm new "$shell" "$dir" "$@"
            compared=$((compared + 1))
            if [ "$status" -ne "$ref_status" ]; then
                bad "[$shell] $label: git modified $spec: exit $status, reference $ref_status; stderr:$nl$(cat "$tmp/new.err")"
            elif ! cmp -s "$tmp/new.out" "$tmp/ref.out"; then
                bad "[$shell] $label: git modified $spec: stdout differs from the reference:$nl$(diff "$tmp/ref.out" "$tmp/new.out" || true)"
            elif ! cmp -s "$tmp/new.err" "$tmp/ref.err"; then
                bad "[$shell] $label: git modified $spec: stderr differs from the reference:$nl$(diff "$tmp/ref.err" "$tmp/new.err" || true)"
            else
                ok
            fi
        done
        IFS=$nl
    done
    IFS=$saved_ifs
    set +f
}

differ "ordinary" "$shells" "$ord" "$worktree_specs$nl$commit_specs"
differ "ordinary, from sub/" "$shells" "$ord/sub" "$worktree_specs$nl$commit_specs"
differ "ordinary, from sub/deep/" "$shells" "$ord/sub/deep" "-$nl-i$nl-- .$nl-i -- ..${nl}HEAD~1"
git -C "$ord" config status.renames copies
differ "ordinary, status.renames=copies" "$shells" "$ord" "-$nl-i$nl-m$nl-q$nl-i -- sub"
differ "ordinary, status.renames=copies, from sub/" "$shells" "$ord/sub" "-$nl-i"
git -C "$ord" config --unset status.renames
differ "unmerged" "$shells" "$unm" "$worktree_specs${nl}HEAD"
differ "unmerged, from sub/" "$shells" "$unm/sub" "-$nl-u$nl-i$nl-u -- .$nl-u -- ..$nl-q -u"
differ "add/add, except -u" "$shells" "$aa" "-$nl-m$nl-i$nl-q$nl-- sub$nl-i -- .${nl}HEAD"
differ "unborn" "$shells" "$unborn" "$worktree_specs${nl}HEAD$nl-q HEAD"
differ "unborn, from sub/" "$shells" "$unborn/sub" "-$nl-i$nl-m$nl-- ."
differ "not a repository" "$shells" "$tmp/norepo" "-$nl-i$nl-u$nl-q${nl}HEAD$nl-h"

# The guard against a vacuous comparison, where both versions fail the same way.
[ "$nonempty" -ge 80 ] || bad "only $nonempty reference runs listed files; the fixtures are broken"
section_done "differential: $compared runs identical to upstream 354262e's git-modified ($nonempty of the reference runs list files)"

# --- The intended difference: -u lists add/add conflicts -------------------------

# expect <label> <expected stdout> <expected stderr> <expected status>
expect() {
    if [ "$status" -ne "$4" ]; then
        bad "$1: exit $status, expected $4; stderr:$nl$(cat "$tmp/new.err")"
    elif [ "$(cat "$tmp/new.out"; echo x)" != "$2${2:+$nl}x" ]; then
        bad "$1: stdout:$nl$(cat "$tmp/new.out")${nl}expected:$nl$2"
    elif [ "$(cat "$tmp/new.err"; echo x)" != "$3${3:+$nl}x" ]; then
        bad "$1: stderr:$nl$(cat "$tmp/new.err")${nl}expected:$nl$3"
    else
        ok
    fi
}

gm old dash "$aa" -u
if [ "$status" -ne 0 ] || [ "$(cat "$tmp/old.out")" != both-modified.txt ]; then
    bad "the reference -u was expected to list only both-modified.txt: $(cat "$tmp/old.out")"
fi
for shell in $shells; do
    gm new "$shell" "$aa" -u
    expect "[$shell] -u with an add/add conflict" "both-added.txt${nl}both-modified.txt" "" 0
    gm new "$shell" "$aa/sub" -u
    expect "[$shell] -u with an add/add conflict, from sub/" "../both-added.txt$nl../both-modified.txt" "" 0
    gm new "$shell" "$aa" -uq
    expect "[$shell] -uq with an add/add conflict" "" "" 0
done
section_done "-u lists add/add conflicts"

# --- 2. Names git quotes, splits or echo mangles -----------------------------------

tab=$(printf '\t')
sp=' '
names="back\\slash.txt
\"quote\".txt
tab${tab}x.txt
a -> b.txt
-leading-dash.txt
 leading-space.txt
trailing-space.txt$sp
with space.txt
café.txt
x\\c.txt
x\\t.txt
x\\n.txt
+plus.txt
glob*[x]?.txt
%s%d.txt"

# sorted <prefix>: the names in git's (byte) order, each with <prefix>.
sorted() {
    printf '%s\n' "$names" | LC_ALL=C sort | while IFS= read -r n; do
        printf '%s%s\n' "$1" "$n"
    done
}

# Prints the ordinary name each tricky name is renamed to.
dest_names() {
    i=0
    printf '%s\n' "$names" | while IFS= read -r n; do
        i=$((i + 1))
        printf 'dest-%02d.txt\n' "$i"
    done
}

# each_name <command> [args]: runs <command> [args] <name> for every name.
each_name() {
    printf '%s\n' "$names" | while IFS= read -r n; do
        "$@" "$n"
    done
}

# check_names <label> <dir> <expected stdout> <args...>
check_names() {
    label=$1 dir=$2 want=$3
    shift 3
    for shell in $shells; do
        gm new "$shell" "$dir" "$@"
        expect "[$shell] $label: git modified $*" "$want" "" 0
    done
}

tr_repo=$tmp/tricky
git init -q "$tr_repo"
mkdir "$tr_repo/sub"
echo k > "$tr_repo/sub/keep.txt"
commit "$tr_repo" first
write_name() { printf '%s\n' "$1" > "$tr_repo/$1"; }
each_name write_name
all=$(sorted "")
all_up=$(sorted "../")

check_names "untracked" "$tr_repo" "$all"
check_names "untracked" "$tr_repo" "$all" -i
check_names "untracked" "$tr_repo" "$all" -- .
check_names "untracked, from sub/" "$tr_repo/sub" "$all_up"
check_names "untracked, from sub/" "$tr_repo/sub" "$all_up" -i -- ..
commit "$tr_repo" "add the names"
check_names "added in a commit" "$tr_repo" "$all" HEAD
check_names "added in a commit, from sub/" "$tr_repo/sub" "$all_up" HEAD
check_names "added in a commit" "$tr_repo" "$all" HEAD -- .
append_name() { echo more >> "$tr_repo/$1"; }
each_name append_name
check_names "modified" "$tr_repo" "$all"
check_names "modified" "$tr_repo" "$all" -m
check_names "modified, from sub/" "$tr_repo/sub" "$all_up" -m
git -C "$tr_repo" add -A
check_names "staged" "$tr_repo" "$all" -i
check_names "staged, from sub/" "$tr_repo/sub" "$all_up" -i
commit "$tr_repo" "modify the names"
check_names "modified in a commit" "$tr_repo" "$all" HEAD

# The names as rename source, then as rename destination.
i=0
fill_name() {
    i=$((i + 1))
    lines $((i * 1000)) > "$tr_repo/$1"
}
each_name fill_name
commit "$tr_repo" "distinct content"
i=0
rename_from() {
    i=$((i + 1))
    git -C "$tr_repo" mv -- "$1" "$(printf 'dest-%02d.txt' "$i")"
}
each_name rename_from
dests=$(dest_names)
check_names "renamed away" "$tr_repo" "$dests" -i
append_dest() { echo more >> "$tr_repo/$1"; }
printf '%s\n' "$dests" | while IFS= read -r d; do append_dest "$d"; done
check_names "renamed away, then modified" "$tr_repo" "$dests"
commit "$tr_repo" "rename away"
check_names "renamed away in a commit" "$tr_repo" "$dests" HEAD
i=0
rename_to() {
    i=$((i + 1))
    git -C "$tr_repo" mv -- "$(printf 'dest-%02d.txt' "$i")" "$1"
}
each_name rename_to
check_names "renamed to" "$tr_repo" "$all" -i
check_names "renamed to, from sub/" "$tr_repo/sub" "$all_up" -i
commit "$tr_repo" "rename back"
check_names "renamed to in a commit" "$tr_repo" "$all" HEAD

# The names as conflicts, add/add included.
both_modified() { unmerge "$tr_repo" 123 "$1"; }
each_name both_modified
check_names "unmerged" "$tr_repo" "$all" -u
check_names "unmerged, from sub/" "$tr_repo/sub" "$all_up" -u
git -C "$tr_repo" reset -q
both_added() { unmerge "$tr_repo" 23 "$1"; }
each_name both_added
check_names "add/add" "$tr_repo" "$all" -u
section_done "names with a backslash, quote, tab, ' -> ', leading dash or plus, spaces, non-ASCII, \\c, \\t, glob or % characters, in every mode"

# --- 3. Names with a newline ------------------------------------------------------

warning="git modified: skipping a filename that contains a newline"
nlr=$tmp/newline
git init -q "$nlr"
lines 1 > "$nlr/ren-src.txt"
lines 100 > "$nlr/src${nl}name.txt"
commit "$nlr" first
echo a > "$nlr/aaa.txt"
echo b > "$nlr/b${nl}c.txt"
echo b > "$nlr/b$nl?? injected.txt"
echo z > "$nlr/zzz.txt"
for shell in $shells; do
    gm new "$shell" "$nlr"
    expect "[$shell] untracked names with a newline" "aaa.txt${nl}zzz.txt" "$warning$nl$warning" 0
    gm new "$shell" "$nlr" -q
    expect "[$shell] -q: names with a newline" "" "" 0
done
commit "$nlr" "add names with a newline"
git -C "$nlr" mv ren-src.txt "ren${nl}dst.txt"
git -C "$nlr" mv "src${nl}name.txt" plain-dst.txt
echo y > "$nlr/yyy.txt"
git -C "$nlr" add yyy.txt
for shell in $shells; do
    gm new "$shell" "$nlr" -i
    expect "[$shell] renamed to and from a name with a newline" "plain-dst.txt${nl}yyy.txt" "$warning" 0
done
commit "$nlr" "rename"
for shell in $shells; do
    gm new "$shell" "$nlr" HEAD
    expect "[$shell] a commit with a name with a newline" "plain-dst.txt${nl}yyy.txt" "$warning" 0
    gm new "$shell" "$nlr" HEAD~1
    expect "[$shell] a commit with names with a newline" "aaa.txt${nl}zzz.txt" "$warning$nl$warning" 0
done
echo n > "$nlr/only${nl}newline.txt"
for shell in $shells; do
    gm new "$shell" "$nlr"
    expect "[$shell] nothing left but a name with a newline" "" "$warning" 1
done
section_done "names with a newline are skipped with a warning, without desync"

echo "$passes checks passed under:$shells"
# Which realpath git-relative-path used (GNU or uutils), for CI logs.
echo "realpath: $(realpath --version 2>/dev/null | head -n 1)"
[ "$failures" -eq 0 ] || die "$failures check(s) failed"
echo "git-modified tests passed"
