#!/bin/sh
#
# Tests for the bare-worktree commands (git clone-worktree, init-worktree,
# convert-worktree, switch-worktree, bare-worktree and bwt).
#
# The commands under test are the ones on the caller's PATH: bare-worktree/
# in a checkout, the extracted bin/ in the release smoke test. Everything
# else runs on a controlled PATH: a throwaway directory holding links to only
# the tools needed (git, sh and a few coreutils), plus stubs for wt and
# zoxide. /usr/bin has both git and, on some machines, zoxide, so reordering
# PATH alone can't prove "no zoxide" or "no wt".
#
# By default wt is a stub that records its arguments. TOOLBELT_TEST_REAL_WT=1
# runs the same checks against Worktrunk itself (TOOLBELT_TEST_WT=<path>
# picks the binary) and also checks that both config samples parse.
#
# Run it with a private umask, e.g. (umask 077; scripts/test-bare-worktree.sh).
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
samples=$root/bare-worktree
real_mode=${TOOLBELT_TEST_REAL_WT:-0}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tmp=$(CDPATH='' cd -P -- "$tmp" && pwd -P)

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

passes=0
ok() {
    passes=$((passes + 1))
    echo "ok: $*"
}

# --- The controlled PATH ---------------------------------------------------

mkdir "$tmp/cmds" "$tmp/sys" "$tmp/stub" "$tmp/zo" "$tmp/realwt" \
    "$tmp/failgit" "$tmp/failrmdir"
for cmd in git-clone-worktree git-init-worktree git-convert-worktree \
    git-switch-worktree git-bare-worktree git-bwt; do
    path=$(command -v "$cmd") || fail "$cmd is not on PATH"
    case $path in /*) ;; *) fail "$cmd does not resolve to a file: $path" ;; esac
    ln -s "$path" "$tmp/cmds/$cmd"
done
for tool in sh git sed tr cat mv mkdir rm cp rmdir grep ls cmp sort tail \
    env ln chmod awk; do
    path=$(command -v "$tool") || fail "$tool is not on PATH"
    case $path in /*) ;; *) fail "$tool does not resolve to a file: $path" ;; esac
    ln -s "$path" "$tmp/sys/$tool"
done
real_git=$(command -v git)

if [ "$real_mode" = 1 ]; then
    real_wt=${TOOLBELT_TEST_WT:-$(command -v wt || true)}
    # A mise shim needs mise's own config, which the fake HOME below hides.
    case $real_wt in
        */shims/wt) real_wt=$(cd / && mise which wt) ;;
    esac
    [ -x "$real_wt" ] || fail "TOOLBELT_TEST_REAL_WT=1 needs wt on PATH (or TOOLBELT_TEST_WT)"
    ln -s "$real_wt" "$tmp/realwt/wt"
    wt_dir=$tmp/realwt
else
    wt_dir=$tmp/stub
fi

# The wt stub records one line per call, each argument in brackets, and
# exits with $WT_STUB_EXIT. The zoxide stub does the same.
cat > "$tmp/stub/wt" <<'EOF'
#!/bin/sh
line=
for arg do line="$line[$arg] "; done
printf '%s\n' "${line% }" >> "$WT_STUB_LOG"
exit "${WT_STUB_EXIT:-0}"
EOF
sed -e 's/WT_STUB_LOG/ZO_STUB_LOG/' -e 's/WT_STUB_EXIT/ZO_STUB_EXIT/' \
    "$tmp/stub/wt" > "$tmp/zo/zoxide"
# A git that fails `git worktree add` (or the git subcommand in $FAILGIT),
# and an rmdir that always fails: they stop git convert-worktree at step 4
# and at step 6.
cat > "$tmp/failgit/git" <<EOF
#!/bin/sh
case " \$* " in *" \${FAILGIT:-worktree add} "*) echo "test: refusing \$*" >&2; exit 97 ;; esac
exec '$real_git' "\$@"
EOF
printf '#!/bin/sh\necho "test: refusing rmdir" >&2\nexit 98\n' > "$tmp/failrmdir/rmdir"
chmod 755 "$tmp/stub/wt" "$tmp/zo/zoxide" "$tmp/failgit/git" "$tmp/failrmdir/rmdir"

p_stub=$tmp/cmds:$tmp/stub:$tmp/sys
p_nowt=$tmp/cmds:$tmp/sys
p_zoxide=$tmp/cmds:$wt_dir:$tmp/zo:$tmp/sys
PATH=$tmp/cmds:$wt_dir:$tmp/sys
export PATH

# --- An isolated environment -------------------------------------------------

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_CONFIG_PARAMETERS GIT_CONFIG_GLOBAL \
    GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL EMAIL
HOME=$tmp/home
XDG_CONFIG_HOME=$tmp/home/.config
GIT_CONFIG_NOSYSTEM=1
_ZO_DATA_DIR=$tmp/zoxide-data
WT_STUB_LOG=$tmp/wt.log
ZO_STUB_LOG=$tmp/zoxide.log
WORKTRUNK_CONFIG_PATH=$tmp/wt.toml
WORKTRUNK_SYSTEM_CONFIG_PATH=$tmp/system.toml
WORKTRUNK_PROJECT_CONFIG_PATH=$tmp/project.toml
WORKTRUNK_WORKTREE_PATH='{{ repo_path }}/../{{ branch | sanitize }}'
export HOME XDG_CONFIG_HOME GIT_CONFIG_NOSYSTEM _ZO_DATA_DIR WT_STUB_LOG \
    ZO_STUB_LOG WORKTRUNK_CONFIG_PATH WORKTRUNK_SYSTEM_CONFIG_PATH \
    WORKTRUNK_PROJECT_CONFIG_PATH WORKTRUNK_WORKTREE_PATH
mkdir -p "$HOME" "$_ZO_DATA_DIR"
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main
git config --global advice.detachedHead false
: > "$WT_STUB_LOG"
: > "$ZO_STUB_LOG"

# run <command...>: stdout to $tmp/out, stderr to $tmp/err, exit in $status.
run() {
    set +e
    "$@" > "$tmp/out" 2> "$tmp/err"
    status=$?
    set -e
}

expect_status() {
    if [ "$status" -ne "$2" ]; then
        echo "--- stdout" >&2
        cat "$tmp/out" >&2
        echo "--- stderr" >&2
        cat "$tmp/err" >&2
        fail "$1: exit $status, expected $2"
    fi
}

expect_eq() {
    if [ "$2" != "$3" ]; then
        printf 'FAIL: %s\n--- actual\n%s\n--- expected\n%s\n' "$1" "$2" "$3" >&2
        exit 1
    fi
}

expect_grep() {
    grep -q -- "$2" "$3" || {
        cat "$3" >&2
        fail "$1: '$2' not in output"
    }
}

expect_no_grep() {
    if grep -q -- "$2" "$3"; then
        cat "$3" >&2
        fail "$1: unexpected '$2' in output"
    fi
}

# entries <dir>: every name in <dir>, dotfiles last, on one line.
entries() {
    names=
    for entry in "$1"/* "$1"/.[!.]* "$1"/..?*; do
        if [ -e "$entry" ] || [ -L "$entry" ]; then
            names="$names ${entry##*/}"
        fi
    done
    printf '%s\n' "${names# }"
}

# The last two stdout lines of the previous run.
last_lines() {
    tail -n 2 "$tmp/out"
}

# stub_log_is <label> <expected> [always]: check, then clear, the wt calls.
# Only meaningful with the stub, unless the run put the stub on PATH itself.
stub_log_is() {
    if [ "$wt_dir" = "$tmp/stub" ] || [ "${3:-}" = always ]; then
        expect_eq "$1: wt calls" "$(cat "$WT_STUB_LOG")" "$2"
    fi
    : > "$WT_STUB_LOG"
}

# What a refusal must leave untouched.
snapshot() {
    (
        cd "$1"
        ls -A
        git config --get core.bare || true
        git status --porcelain=v2 --ignored 2> /dev/null || true
    )
}

preflight_message() {
    cat <<EOF
$1: Worktrunk (wt) is required but was not found on PATH.
  Install: https://github.com/max-sixty/worktrunk#install
  Setup:   https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/getting-started.md#setting-up-worktrunk
EOF
}

bw_usage='usage: git bare-worktree <clone|convert|init|switch> [args...]
       git bare-worktree config-example [--project]'

# A source repository with a slashed default branch.
source=$tmp/source.git
git init -q -b release/stable "$source"
git -C "$source" commit -q --allow-empty -m initial
cd "$tmp"

# --- Help and usage -------------------------------------------------------------

for verb in clone-worktree init-worktree convert-worktree; do
    case $verb in
        clone-worktree) line='usage: git clone-worktree <repository> [directory]' ;;
        init-worktree) line='usage: git init-worktree <directory> [--branch <name>]' ;;
        convert-worktree) line='usage: git convert-worktree [path] [--dry-run]' ;;
    esac
    for flag in -h --help; do
        # git turns `git <verb> --help` into `git help <verb>`; call the
        # script by its git-<verb> name to reach its own --help.
        run env PATH="$p_nowt" "git-$verb" "$flag"
        expect_status "git-$verb $flag" 0
        expect_eq "git-$verb $flag" "$(cat "$tmp/out")" "$line"
    done
    run env PATH="$p_nowt" git "$verb" -h
    expect_status "git $verb -h" 0
    expect_eq "git $verb -h" "$(cat "$tmp/out")" "$line"
done
ok "-h and --help print the usage line, without wt"

for args in "clone-worktree" "clone-worktree -x" "clone-worktree a b c" \
    "init-worktree" "init-worktree a b" "init-worktree a --branch" "init-worktree --bogus a" \
    "convert-worktree --bogus" "convert-worktree a b"; do
    # shellcheck disable=SC2086 # split the argument list on purpose
    run git $args
    expect_status "git $args" 2
    expect_grep "git $args" '^usage: git ' "$tmp/err"
    [ ! -s "$tmp/out" ] || fail "git $args: usage error wrote to stdout"
done
[ ! -e a ] || fail "a usage error created a file"
ok "bad usage exits 2 with the usage line on stderr"

for form in bare-worktree bwt; do
    run env PATH="$p_nowt" git "$form"
    expect_status "git $form" 2
    expect_eq "git $form: usage" "$(cat "$tmp/err")" "$bw_usage"
    run env PATH="$p_nowt" git "$form" -h
    expect_status "git $form -h" 0
    expect_eq "git $form -h" "$(cat "$tmp/out")" "$bw_usage"
    run env PATH="$p_nowt" git "$form" bogus
    expect_status "git $form bogus" 2
    expect_grep "git $form bogus" "^git bare-worktree: unknown action 'bogus'" "$tmp/err"
    run env PATH="$p_nowt" git "$form" config-example --bogus
    expect_status "git $form config-example --bogus" 2
done
run env PATH="$p_nowt" git-bare-worktree --help
expect_status "git-bare-worktree --help" 0
expect_eq "git-bare-worktree --help" "$(cat "$tmp/out")" "$bw_usage"
ok "git bare-worktree and git bwt: long-name usage; no or unknown action exits 2, -h exits 0"

# Regression: help for a verb through the dispatcher needs no wt either.
for form in "bwt clone" "bare-worktree init"; do
    # shellcheck disable=SC2086 # split the argument list on purpose
    run env PATH="$p_nowt" git $form -h
    expect_status "git $form -h without wt" 0
    expect_grep "git $form -h without wt" '^usage: git ' "$tmp/out"
done
ok "git bwt <verb> -h prints the verb's usage without wt, like git <verb>-worktree -h"

# --- Config samples ---------------------------------------------------------

for form in bare-worktree bwt; do
    env PATH="$p_nowt" git "$form" config-example > "$tmp/user.toml"
    cmp "$tmp/user.toml" "$samples/config.toml.example" ||
        fail "git $form config-example differs from bare-worktree/config.toml.example"
    env PATH="$p_nowt" git "$form" config-example --project > "$tmp/project-sample.toml"
    cmp "$tmp/project-sample.toml" "$samples/wt.toml.example" ||
        fail "git $form config-example --project differs from bare-worktree/wt.toml.example"
done
ok "config-example output is byte-identical to both .example files, without wt"

# --- Preflight: no wt on PATH -----------------------------------------------

convert_me=$tmp/preflight-repo
git init -q "$convert_me"
git -C "$convert_me" commit -q --allow-empty -m initial
before=$(snapshot "$convert_me")
for spec in "git-clone-worktree|clone-worktree $source nowt-clone" \
    "git-init-worktree|init-worktree nowt-init" \
    "git-convert-worktree|convert-worktree $convert_me" \
    "git-switch-worktree|switch-worktree -c nowt-switch" \
    "git-bare-worktree|bare-worktree clone $source nowt-bw-clone" \
    "git-bare-worktree|bare-worktree init nowt-bw-init" \
    "git-bare-worktree|bwt clone $source nowt-bwt-clone" \
    "git-bare-worktree|bwt init nowt-bwt-init" \
    "git-bare-worktree|bwt convert $convert_me" \
    "git-bare-worktree|bwt switch -c nowt-switch"; do
    name=${spec%%|*}
    # shellcheck disable=SC2086 # split the argument list on purpose
    run env PATH="$p_nowt" git ${spec#*|}
    expect_status "no wt: git ${spec#*|}" 1
    expect_eq "no wt: git ${spec#*|}" "$(cat "$tmp/err")" "$(preflight_message "git ${name#git-}")"
done
for dir in nowt-clone nowt-init nowt-bw-clone nowt-bw-init nowt-bwt-clone nowt-bwt-init; do
    [ ! -e "$dir" ] || fail "no wt: $dir was created"
done
expect_eq "no wt: convert left the repo alone" "$(snapshot "$convert_me")" "$before"
ok "without wt every command, git bare-worktree and git bwt included, fails the preflight and creates nothing"

# --- git clone-worktree -------------------------------------------------------

run git clone-worktree "$source" "checkout with spaces"
expect_status "clone" 0
destination="$tmp/checkout with spaces"
[ "$(git --git-dir="$destination/.git" rev-parse --is-bare-repository)" = true ]
[ "$(git -C "$destination" config remote.origin.fetch)" = '+refs/heads/*:refs/remotes/origin/*' ]
[ "$(git -C "$destination" symbolic-ref refs/remotes/origin/HEAD)" = refs/remotes/origin/release/stable ]
[ "$(git -C "$destination/release-stable" branch --show-current)" = release/stable ]
[ "$(git -C "$destination/release-stable" rev-parse --abbrev-ref '@{upstream}')" = origin/release/stable ]
expect_eq "clone output" "$(last_lines)" "Checkout: $destination/release-stable
Next:     cd '$destination/release-stable'   # or: wt -C '$destination' switch release/stable"
expect_no_grep "clone without zoxide" zoxide "$tmp/err"
stub_log_is "clone" "[-C] [$destination] [switch] [release/stable] [--no-cd] [--no-hooks]"
ok "clone: bare .git, refspec, origin/HEAD, upstream, sanitized folder, final wt switch, quoted Next line"

# New remote branches must be available on an ordinary subsequent fetch.
git -C "$source" branch remote-feature
git -C "$destination/release-stable" fetch -q origin
git -C "$destination" show-ref --verify --quiet refs/remotes/origin/remote-feature
ok "clone: a later plain fetch picks up new remote branches"

mkdir inferred
(cd inferred && git clone-worktree "$source" > /dev/null 2>&1)
[ -d inferred/source/release-stable ]
: > "$WT_STUB_LOG"
# Regression: a path ending in /.git names the folder after its parent,
# like git clone.
mkdir dotgit
run sh -c 'cd dotgit && git clone-worktree "$1"' sh "$source/.git"
expect_status "clone of <path>/.git" 0
[ -d dotgit/source/release-stable ] || fail "clone of <path>/.git: wrong folder name"
: > "$WT_STUB_LOG"
# Regression: missing parent folders are created, as git clone does.
run git clone-worktree "$source" deep/a/b
expect_status "clone into deep/a/b" 0
[ -d deep/a/b/release-stable ] || fail "clone into deep/a/b: no checkout"
: > "$WT_STUB_LOG"
ok "clone: the directory defaults to the repository name, also for <path>/.git; missing parents are created"

expect_failure() {
    expected=$1
    shift
    run "$@"
    [ "$status" -ne 0 ] || fail "expected failure: $*"
    expect_grep "$*" "$expected" "$tmp/err"
}
expect_failure 'invalid destination' git clone-worktree "$source" ""
expect_failure 'already exists' git clone-worktree "$source" "checkout with spaces"
[ "$(git -C "$destination/release-stable" branch --show-current)" = release/stable ]
mkdir empty
expect_failure 'already exists' git clone-worktree "$source" empty
[ ! -e empty/.git ]
ln -s nonexistent symlink
expect_failure 'already exists' git clone-worktree "$source" symlink
[ -L symlink ]
expect_failure 'does not exist' git clone-worktree "$tmp/nonexistent.git" failed
git init -q --bare "$tmp/empty-remote.git"
expect_failure 'Cannot determine remote HEAD' git clone-worktree "$tmp/empty-remote.git" empty-clone
# Regression: a failure after the bare clone leaves nothing behind.
[ ! -e empty-clone ] || fail "a failed clone left empty-clone/ behind"
: > "$WT_STUB_LOG"
ok "clone: refuses an existing destination (dir, empty dir, symlink) and reports git failures"

if [ "$real_mode" = 1 ]; then
    wt -C "$destination/release-stable" switch --create feature/auth --no-cd --no-hooks > /dev/null 2>&1
    [ -d "$destination/feature-auth" ]
    ok "real wt: wt switch --create in a cloned layout makes a sibling folder"
fi

# --- git init-worktree --------------------------------------------------------

run git init-worktree "$tmp/init-default"
expect_status "init" 0
[ "$(git -C "$tmp/init-default" rev-parse --is-bare-repository)" = true ]
expect_eq "init: layout" "$(entries "$tmp/init-default")" "main .git"
[ "$(git -C "$tmp/init-default/main" branch --show-current)" = main ]
[ "$(git -C "$tmp/init-default/main" rev-list --count HEAD)" = 1 ]
expect_eq "init output" "$(last_lines)" "Checkout: $tmp/init-default/main
Next:     cd $tmp/init-default/main   # or: wt -C $tmp/init-default switch main"
stub_log_is "init" "[-C] [$tmp/init-default] [switch] [main] [--no-cd] [--no-hooks]"
ok "init: bare .git, a main/ worktree, one commit, final wt switch"

git config --global init.defaultBranch trunk
run git init-worktree init-trunk
expect_status "init with init.defaultBranch" 0
[ "$(git -C init-trunk/trunk branch --show-current)" = trunk ]
git config --global init.defaultBranch main
run git init-worktree init-slash --branch feature/x
expect_status "init --branch" 0
[ "$(git -C init-slash/feature-x branch --show-current)" = feature/x ]
run git init-worktree --branch=dev init-eq
expect_status "init --branch=" 0
[ "$(git -C init-eq/dev branch --show-current)" = dev ]
: > "$WT_STUB_LOG"
# Regression: missing parent folders are created, as git init does.
run git init-worktree deep/x/y
expect_status "init into deep/x/y" 0
[ "$(git -C deep/x/y/main rev-list --count HEAD)" = 1 ] || fail "init into deep/x/y: no root commit"
: > "$WT_STUB_LOG"
ok "init: init.defaultBranch is respected; --branch <name> and --branch=<name> win, with a sanitized folder; missing parents are created"

mkdir init-exists
run git init-worktree init-exists
expect_status "init into an empty dir" 1
expect_grep "init into an empty dir" "^git init-worktree: 'init-exists' already exists" "$tmp/err"
[ -z "$(ls -A init-exists)" ] || fail "init wrote into an existing directory"
run git init-worktree init-badbranch --branch 'a..b'
expect_status "init with an invalid branch" 1
[ ! -e init-badbranch ] || fail "init with an invalid branch created files"
run git -c user.useConfigOnly=true -c user.name= -c user.email= init-worktree init-noident
expect_status "init without an identity" 1
expect_grep "init without an identity" "^git init-worktree: set user.name and user.email first" "$tmp/err"
[ ! -e init-noident ] || fail "init without an identity created files"
: > "$WT_STUB_LOG"
ok "init: refuses an existing (even empty) dir, a bad branch name or a missing identity, creating nothing"

# Regression: the root commit skips your commit hooks.
mkdir "$tmp/hooks"
printf '#!/bin/sh\nexit 1\n' > "$tmp/hooks/pre-commit"
chmod 755 "$tmp/hooks/pre-commit"
run git -c core.hooksPath="$tmp/hooks" init-worktree init-hooks
expect_status "init with a failing pre-commit hook" 0
[ "$(git -C init-hooks/main rev-list --count HEAD)" = 1 ]
# Regression: a failure after the folder was created removes it.
run git -c commit.gpgSign=true -c gpg.program=false init-worktree init-signfail
[ "$status" -ne 0 ] || fail "init with a failing gpg succeeded"
[ ! -e init-signfail ] || fail "a failed init left init-signfail/ behind"
: > "$WT_STUB_LOG"
ok "init: commit hooks don't run for the root commit; a failed init removes what it created"

# Regression: an exported GIT_DIR must not send the root commit to another
# repository.
git init -q "$tmp/other"
git -C "$tmp/other" commit -q --allow-empty -m other
run env GIT_DIR="$tmp/other/.git" git init-worktree init-gitdir
expect_status "init with GIT_DIR exported" 0
[ "$(git -C "$tmp/other" rev-list --count HEAD)" = 1 ] || fail "init committed into \$GIT_DIR"
[ "$(git -C init-gitdir/main rev-list --count HEAD)" = 1 ]
: > "$WT_STUB_LOG"
ok "init: an exported GIT_DIR is ignored"

# --- git convert-worktree -----------------------------------------------------

# A remote whose default branch is main, with a tracked top-level main/
# directory: the name the new worktree folder will take.
convert_src=$tmp/convert-src
git init -q -b main "$convert_src"
mkdir "$convert_src/main"
echo tracked > "$convert_src/main/file"
echo a > "$convert_src/a.txt"
printf 'ignored.log\n' > "$convert_src/.gitignore"
git -C "$convert_src" add .
git -C "$convert_src" commit -q -m initial

# make_dirty <repo>: a modified, a staged, an untracked, an ignored file and
# an untracked dotfile.
make_dirty() {
    echo modified >> "$1/a.txt"
    echo staged > "$1/staged.txt"
    git -C "$1" add staged.txt
    echo untracked > "$1/untracked.txt"
    echo ignored > "$1/ignored.log"
    echo dotfile > "$1/.envrc"
}

repo=$tmp/convert
git clone -q "$convert_src" "$repo"
make_dirty "$repo"
git -C "$repo" worktree add -q "$tmp/outside" -b outside
git -C "$repo" worktree add -q "$repo/.claude/worktrees/nested" -b nested
status_before=$(git -C "$repo" status --porcelain=v2 --ignored)
reflog_before=$(git -C "$repo" reflog --format=%gs)
[ -n "$status_before" ]

before=$(snapshot "$repo")
run git convert-worktree --dry-run "$repo"
expect_status "convert --dry-run" 0
expect_grep "convert --dry-run" '^Dry run: nothing was changed.' "$tmp/out"
expect_grep "convert --dry-run" "$repo/.claude/worktrees/nested -> $repo/main/.claude/worktrees/nested" "$tmp/out"
expect_eq "convert --dry-run changed nothing" "$(snapshot "$repo")" "$before"
cp "$tmp/out" "$tmp/dry-run-verb"
for form in "bare-worktree convert" "bwt convert"; do
    # shellcheck disable=SC2086 # split the argument list on purpose
    run git $form --dry-run "$repo"
    expect_status "git $form --dry-run" 0
    cmp "$tmp/out" "$tmp/dry-run-verb" || fail "git $form --dry-run differs from git convert-worktree --dry-run"
done
stub_log_is "convert --dry-run" "" always
ok "convert --dry-run: prints the plan, changes nothing, calls no wt; same via git bare-worktree and git bwt"

# Run from a subfolder (the tracked main/), without a path.
run sh -c 'cd "$1/main" && git convert-worktree' sh "$repo"
expect_status "convert" 0
[ "$(git -C "$repo" rev-parse --is-bare-repository)" = true ]
expect_eq "convert: container" "$(entries "$repo")" "main .git"
expect_eq "convert: status survives" "$(git -C "$repo/main" status --porcelain=v2 --ignored)" "$status_before"
[ "$(cat "$repo/main/main/file")" = tracked ] || fail "convert: tracked main/ directory lost"
[ "$(git -C "$repo/main" branch --show-current)" = main ]
[ "$(git -C "$repo/main" rev-parse --abbrev-ref '@{upstream}')" = origin/main ]
expect_eq "convert: HEAD reflog" "$(git -C "$repo/main" reflog --format=%gs)" "$reflog_before"
[ "$(git -C "$repo" config remote.origin.fetch)" = '+refs/heads/*:refs/remotes/origin/*' ]
git -C "$repo/main/.claude/worktrees/nested" status --porcelain > /dev/null
[ "$(git -C "$repo/main/.claude/worktrees/nested" branch --show-current)" = nested ]
git -C "$tmp/outside" status --porcelain > /dev/null
[ "$(git -C "$tmp/outside" branch --show-current)" = outside ]
git -C "$repo/main" worktree list --porcelain > "$tmp/worktrees"
expect_grep "convert: nested worktree repaired" "^worktree $repo/main/.claude/worktrees/nested\$" "$tmp/worktrees"
expect_no_grep "convert: no prunable worktree" '^prunable' "$tmp/worktrees"
# Regression: the hint counts only the worktree outside the repo, not the
# nested one that was just repaired.
expect_grep "convert: relocate hint" "^Hint:     1 linked worktree(s) outside the repo .* wt -C $repo/main step relocate --dry-run" "$tmp/out"
expect_eq "convert output" "$(last_lines)" "Checkout: $repo/main
Next:     cd $repo/main   # or: wt -C $repo switch main"
stub_log_is "convert" "[-C] [$repo] [switch] [main] [--no-cd] [--no-hooks]"
ok "convert: modified, staged, untracked, ignored and dot files survive; tracked main/ doesn't collide"
ok "convert: upstream and reflog carried over; refspec kept"
ok "convert: an outside linked worktree still works and a nested one is repaired"

# With extensions.worktreeConfig, core.bare must not reach the linked
# worktrees, and the main worktree's own settings move to the new one.
repo=$tmp/convert-wtconfig
git clone -q "$convert_src" "$repo"
git -C "$repo" worktree add -q "$tmp/outside-wtconfig" -b outside-wtconfig
git -C "$repo" config extensions.worktreeConfig true
git -C "$repo" config --worktree test.marker kept
run git convert-worktree "$repo"
expect_status "convert with extensions.worktreeConfig" 0
[ "$(git -C "$repo" rev-parse --is-bare-repository)" = true ]
[ "$(git -C "$repo/main" rev-parse --is-bare-repository)" = false ]
[ "$(git -C "$tmp/outside-wtconfig" rev-parse --is-bare-repository)" = false ]
git -C "$repo/main" status --porcelain > /dev/null
[ "$(git -C "$repo/main" config --worktree test.marker)" = kept ] || fail "convert: config.worktree not carried over"
[ -z "$(git -C "$repo" config --worktree --get test.marker || true)" ] || fail "convert: the bare repo kept config.worktree settings"
: > "$WT_STUB_LOG"
ok "convert with extensions.worktreeConfig: only the container is bare; config.worktree moves to the new worktree"

# Regression: `git --git-dir=<repo>/.git --work-tree=<repo> convert-worktree
# <repo>` exports GIT_DIR, which used to make step 5 copy .git onto itself.
repo=$tmp/convert-gitdir
git clone -q "$convert_src" "$repo"
make_dirty "$repo"
status_gitdir=$(git -C "$repo" status --porcelain=v2 --ignored)
run git --git-dir="$repo/.git" --work-tree="$repo" convert-worktree "$repo"
expect_status "convert with GIT_DIR and GIT_WORK_TREE exported" 0
[ "$(git -C "$repo" rev-parse --is-bare-repository)" = true ]
expect_eq "convert with GIT_DIR: status" "$(git -C "$repo/main" status --porcelain=v2 --ignored)" "$status_gitdir"
git clone -q "$convert_src" "$tmp/convert-gitdir-other"
before=$(snapshot "$tmp/convert-gitdir-other")
run env GIT_DIR="$convert_src/.git" git convert-worktree "$tmp/convert-gitdir-other"
expect_status "convert with a GIT_DIR for another repository" 1
expect_grep "convert with another GIT_DIR" "^git convert-worktree: GIT_DIR ($convert_src/.git) is not the git directory of" "$tmp/err"
expect_eq "convert with another GIT_DIR: nothing changed" "$(snapshot "$tmp/convert-gitdir-other")" "$before"
: > "$WT_STUB_LOG"
ok "convert: an exported GIT_DIR/GIT_WORK_TREE for the same repo works; one for another repo is refused"

# Regression: a split index keeps its shared index.
repo=$tmp/convert-split
git clone -q "$convert_src" "$repo"
git -C "$repo" config core.splitIndex true
git -C "$repo" update-index --split-index
make_dirty "$repo"
for shared in "$repo"/.git/sharedindex.*; do
    [ -f "$shared" ] || fail "test setup: no shared index"
done
status_split=$(git -C "$repo" status --porcelain=v2 --ignored)
run git convert-worktree "$repo"
expect_status "convert with a split index" 0
expect_eq "convert with a split index: status" "$(git -C "$repo/main" status --porcelain=v2 --ignored)" "$status_split"
: > "$WT_STUB_LOG"
ok "convert: a split index (core.splitIndex) survives"

# Regression: a failed repair names the paths to repair.
repo=$tmp/convert-repairfail
git clone -q "$convert_src" "$repo"
git -C "$repo" worktree add -q "$repo/.claude/worktrees/nested" -b nested
run env FAILGIT="worktree repair" PATH="$tmp/cmds:$tmp/failgit:$wt_dir:$tmp/sys" git-convert-worktree "$repo"
expect_status "convert with a failing repair" 0
expect_grep "convert with a failing repair" "^git convert-worktree: warning: 'git worktree repair' failed; rerun it: git -C $repo/main worktree repair $repo/main/.claude/worktrees/nested\$" "$tmp/err"
: > "$WT_STUB_LOG"
ok "convert: a failing repair only warns, with the exact repair command"

# Regression: a signal during the moves doesn't stop the conversion halfway.
# The mv below interrupts git convert-worktree the first time it runs.
mkdir "$tmp/sigmv"
cat > "$tmp/sigmv/mv" <<EOF
#!/bin/sh
if [ ! -e '$tmp/sigmv/sent' ]; then
    : > '$tmp/sigmv/sent'
    kill -INT "\$PPID"
    kill -HUP "\$PPID"
fi
exec '$(command -v mv)' "\$@"
EOF
chmod 755 "$tmp/sigmv/mv"
repo=$tmp/convert-signal
git clone -q "$convert_src" "$repo"
run env PATH="$tmp/cmds:$tmp/sigmv:$wt_dir:$tmp/sys" git-convert-worktree "$repo"
[ -e "$tmp/sigmv/sent" ] || fail "test setup: the signal was never sent"
expect_status "convert interrupted during step 2" 0
expect_eq "convert interrupted: container" "$(entries "$repo")" "main .git"
: > "$WT_STUB_LOG"
ok "convert: INT and HUP during the moves don't stop it halfway"

# Regression: a directory that can't be moved is found before step 2, not
# halfway through it.
new_repo_dir=$tmp/convert-readonly
git clone -q "$convert_src" "$new_repo_dir"
mkdir "$new_repo_dir/zz-readonly"
chmod a-w "$new_repo_dir/zz-readonly"
before=$(snapshot "$new_repo_dir")
run git convert-worktree "$new_repo_dir"
chmod u+w "$new_repo_dir/zz-readonly"
expect_status "convert with a read-only directory" 1
expect_grep "convert with a read-only directory" "^git convert-worktree: '$new_repo_dir/zz-readonly' is not writable" "$tmp/err"
expect_eq "convert with a read-only directory: nothing changed" "$(snapshot "$new_repo_dir")" "$before"
ok "convert: a directory it can't move is refused up front, changing nothing"

# Regression: never empty the home directory into a worktree.
repo=$tmp/convert-home
git clone -q "$convert_src" "$repo"
before=$(snapshot "$repo")
run env HOME="$repo" git convert-worktree "$repo"
expect_status "convert of \$HOME" 1
expect_grep "convert of \$HOME" "is your home directory or /" "$tmp/err"
expect_eq "convert of \$HOME: nothing changed" "$(snapshot "$repo")" "$before"
ok "convert: refuses when the repository is \$HOME"

# A custom refspec is never overwritten.
repo=$tmp/convert-refspec
git clone -q "$convert_src" "$repo"
git -C "$repo" config remote.origin.fetch '+refs/heads/main:refs/remotes/origin/main'
run git convert-worktree "$repo"
expect_status "convert with a custom refspec" 0
expect_eq "convert: custom refspec" "$(git -C "$repo" config --get-all remote.origin.fetch)" \
    '+refs/heads/main:refs/remotes/origin/main'
ok "convert: a custom remote.origin.fetch is left untouched"

# An origin with no refspec gets the standard one; an unreachable origin
# makes set-head fail, which only warns.
repo=$tmp/convert-norefspec
git init -q "$repo"
git -C "$repo" commit -q --allow-empty -m initial
git -C "$repo" remote add origin "$tmp/missing-remote.git"
git -C "$repo" config --unset remote.origin.fetch
run git convert-worktree "$repo"
expect_status "convert with an unreachable origin" 0
[ "$(git -C "$repo" config remote.origin.fetch)" = '+refs/heads/*:refs/remotes/origin/*' ]
expect_grep "convert: set-head warning" "^git convert-worktree: warning: 'git remote set-head origin --auto' failed" "$tmp/err"
: > "$WT_STUB_LOG"
ok "convert: an unset refspec gets the standard one; a failing set-head only warns"

# Refusals: each leaves the repo exactly as it was.
refuse_case() {
    label=$1
    reason=$2
    target=$3
    snap=${4:-$3}
    before=$(snapshot "$snap")
    run git convert-worktree "$target"
    expect_status "convert refuses $label" 1
    expect_grep "convert refuses $label" "^git convert-worktree: .*$reason" "$tmp/err"
    expect_eq "convert refuses $label: nothing changed" "$(snapshot "$snap")" "$before"
}
new_repo() {
    rm -rf "$tmp/refuse"
    git clone -q "$convert_src" "$tmp/refuse"
}

new_repo
git -C "$tmp/refuse" worktree add -q "$tmp/refuse-linked" -b linked
refuse_case "a linked worktree" "is a linked worktree" "$tmp/refuse-linked" "$tmp/refuse"
git clone -q --bare "$convert_src" "$tmp/refuse-bare.git"
refuse_case "a bare repository" "already a bare repository" "$tmp/refuse-bare.git"
refuse_case "a converted repository" "already a bare repository" "$tmp/convert"
new_repo
git -C "$tmp/refuse" checkout -q --detach
refuse_case "a detached HEAD" "HEAD is detached" "$tmp/refuse"
rm -rf "$tmp/refuse"
git init -q "$tmp/refuse"
refuse_case "an unborn branch" "has no commits yet" "$tmp/refuse"
new_repo
git -C "$tmp/refuse" switch -q -c other
echo other > "$tmp/refuse/a.txt"
git -C "$tmp/refuse" commit -q -am other
git -C "$tmp/refuse" switch -q main
echo main > "$tmp/refuse/a.txt"
git -C "$tmp/refuse" commit -q -am main
git -C "$tmp/refuse" merge -q other > /dev/null 2>&1 || true
[ -f "$tmp/refuse/.git/MERGE_HEAD" ] || fail "test setup: no merge in progress"
refuse_case "a merge in progress" "a merge is in progress" "$tmp/refuse"
new_repo
git -C "$tmp/refuse" -c protocol.file.allow=always submodule add -q "$convert_src" sub > /dev/null 2>&1
[ -d "$tmp/refuse/.git/modules" ] || fail "test setup: no submodule"
refuse_case "a submodule" "submodules are initialised" "$tmp/refuse"
new_repo
git -C "$tmp/refuse" config core.sparseCheckout true
refuse_case "sparse checkout" "sparse checkout is on" "$tmp/refuse"
mkdir "$tmp/not-a-repo"
refuse_case "a plain directory" "is not inside a git repository" "$tmp/not-a-repo"
new_repo
: > "$tmp/refuse/.git/index.lock"
refuse_case "a held index.lock" "index.lock' exists" "$tmp/refuse"
rm -f "$tmp/refuse/.git/index.lock"
stub_log_is "convert refusals" "" always
ok "convert refuses, changing nothing: linked worktree, bare, detached, unborn, merge, submodule, sparse, no repo"

# A failure partway prints recovery commands; running them restores the
# clone exactly. Stop once at step 4 (git worktree add) and once at step 6
# (the last rmdir, after every file has moved into the new worktree).
for stop in "4|$tmp/failgit" "6|$tmp/failrmdir"; do
    new_repo
    repo=$tmp/refuse
    make_dirty "$repo"
    if [ "${stop%%|*}" = 6 ]; then
        git -C "$repo" config extensions.worktreeConfig true
        git -C "$repo" config --worktree test.marker kept
    else
        # Regression: an outside worktree that is unreachable right now (an
        # unmounted disk) keeps its record and its staged change; recovery
        # used to run `git worktree prune`.
        rm -rf "$tmp/away" "$tmp/away.hidden"
        git -C "$repo" worktree add -q "$tmp/away" -b away
        echo away > "$tmp/away/away.txt"
        git -C "$tmp/away" add away.txt
        mv "$tmp/away" "$tmp/away.hidden"
    fi
    worktrees_before=$(git -C "$repo" worktree list --porcelain | grep -c '^worktree ')
    before=$(snapshot "$repo")
    # Called by its file name: git puts its exec-path, which holds another
    # git, ahead of PATH for subcommands.
    run env PATH="$tmp/cmds:${stop#*|}:$wt_dir:$tmp/sys" git-convert-worktree "$repo"
    [ "$status" -ne 0 ] || fail "convert with a failure at step ${stop%%|*} succeeded"
    expect_grep "convert failure at step ${stop%%|*}" "stopped at step ${stop%%|*}; nothing was rolled back" "$tmp/err"
    sed -n 's/^    //p' "$tmp/err" > "$tmp/recovery.sh"
    [ -s "$tmp/recovery.sh" ] || fail "no recovery commands printed"
    sh -eu "$tmp/recovery.sh" || {
        cat "$tmp/err" >&2
        fail "recovery commands failed (step ${stop%%|*})"
    }
    expect_eq "recovery after step ${stop%%|*}" "$(snapshot "$repo")" "$before"
    git -C "$repo" worktree list --porcelain > "$tmp/worktrees"
    expect_eq "recovery after step ${stop%%|*}: worktrees" "$(grep -c '^worktree ' "$tmp/worktrees")" "$worktrees_before"
    if [ "${stop%%|*}" = 6 ]; then
        expect_eq "recovery: config.worktree" "$(git -C "$repo" config --worktree --list)" test.marker=kept
    else
        mv "$tmp/away.hidden" "$tmp/away"
        expect_eq "recovery: the unreachable worktree" "$(git -C "$tmp/away" status --porcelain)" "A  away.txt"
    fi
done
: > "$WT_STUB_LOG"
ok "convert: a failure at step 4, or at step 6 with extensions.worktreeConfig, prints recovery commands that restore the clone exactly, sparing unreachable worktrees"

# --- zoxide ---------------------------------------------------------------------

: > "$ZO_STUB_LOG"
run env PATH="$p_zoxide" git clone-worktree "$source" zo-clone
expect_status "clone with zoxide" 0
expect_eq "clone: zoxide add" "$(cat "$ZO_STUB_LOG")" "[add] [$tmp/zo-clone/release-stable]"
expect_eq "clone with zoxide: Next" "$(tail -n 1 "$tmp/out")" \
    "Next:     cd $tmp/zo-clone/release-stable   # or: wt -C $tmp/zo-clone switch release/stable   |   z zo-clone release-stable"
: > "$ZO_STUB_LOG"
run env PATH="$p_zoxide" git init-worktree zo-init
expect_status "init with zoxide" 0
expect_eq "init: zoxide add" "$(cat "$ZO_STUB_LOG")" "[add] [$tmp/zo-init/main]"
expect_grep "init with zoxide: Next" '   |   z zo-init main$' "$tmp/out"
: > "$ZO_STUB_LOG"
git clone -q "$convert_src" "$tmp/zo-convert"
run env PATH="$p_zoxide" git convert-worktree "$tmp/zo-convert"
expect_status "convert with zoxide" 0
expect_eq "convert: zoxide add" "$(cat "$ZO_STUB_LOG")" "[add] [$tmp/zo-convert/main]"
expect_grep "convert with zoxide: Next" '   |   z zo-convert main$' "$tmp/out"
ok "zoxide on PATH: clone, init and convert run 'zoxide add <checkout>' and print the z hint"

run git init-worktree zo-absent
expect_status "init without zoxide" 0
expect_no_grep "init without zoxide: no output" zoxide "$tmp/err"
expect_no_grep "init without zoxide: no hint" '|   z ' "$tmp/out"
ok "no zoxide on PATH: no error, no zoxide output, no z hint"

run env PATH="$p_zoxide" ZO_STUB_EXIT=1 git init-worktree zo-failing
expect_status "init with a failing zoxide" 0
expect_grep "init with a failing zoxide" "^git init-worktree: warning: 'zoxide add' failed" "$tmp/err"
[ -d zo-failing/main ]
: > "$ZO_STUB_LOG"
: > "$WT_STUB_LOG"
ok "a failing zoxide only warns; the command exits 0"

# --- A failing wt switch --------------------------------------------------------

git clone -q "$convert_src" "$tmp/wtfail-convert"
for spec in "clone-worktree|clone-worktree $source wtfail-clone|$tmp/wtfail-clone/release-stable" \
    "init-worktree|init-worktree wtfail-init|$tmp/wtfail-init/main" \
    "convert-worktree|convert-worktree $tmp/wtfail-convert|$tmp/wtfail-convert/main"; do
    verb=${spec%%|*}
    rest=${spec#*|}
    # shellcheck disable=SC2086 # split the argument list on purpose
    run env PATH="$p_stub" WT_STUB_EXIT=1 git ${rest%|*}
    expect_status "$verb with a failing wt" 0
    expect_grep "$verb with a failing wt" "^git $verb: warning: 'wt switch' failed (exit 1)" "$tmp/err"
    expect_grep "$verb with a failing wt" "^Checkout: ${rest##*|}\$" "$tmp/out"
done
: > "$WT_STUB_LOG"
ok "a failing final wt switch warns and still exits 0 (clone, init, convert)"

# --- git switch-worktree and the dispatcher -------------------------------------

for form in switch-worktree "bare-worktree switch" "bwt switch"; do
    # shellcheck disable=SC2086 # split the argument list on purpose
    run env PATH="$p_stub" git $form -c x --no-cd
    expect_status "git $form" 0
    stub_log_is "git $form" "[switch] [-c] [x] [--no-cd]" always
    # shellcheck disable=SC2086 # split the argument list on purpose
    run env PATH="$p_stub" WT_STUB_EXIT=3 git $form -h
    expect_status "git $form exit code" 3
    stub_log_is "git $form -h" "[switch] [-h]" always
done
ok "git switch-worktree (also via bare-worktree and bwt) passes arguments and exit code through to wt switch"

for action in "clone|$source r" "init|r --branch dev"; do
    for form in "${action%%|*}-worktree" "bare-worktree ${action%%|*}" "bwt ${action%%|*}"; do
        dir=$tmp/eq/$(printf '%s' "$form" | tr ' ' '_')
        mkdir -p "$dir"
        # shellcheck disable=SC2086 # split the argument list on purpose
        (cd "$dir" && env PATH="$p_stub" git $form ${action#*|} > out 2> /dev/null)
        tail -n 2 "$dir/out" | sed "s|$dir|<dir>|g" > "$dir/result"
        sed "s|$dir|<dir>|g" "$WT_STUB_LOG" >> "$dir/result"
        ls -A "$dir/r" >> "$dir/result"
        : > "$WT_STUB_LOG"
    done
    first=$tmp/eq/${action%%|*}-worktree
    cmp "$first/result" "$tmp/eq/bare-worktree_${action%%|*}/result" ||
        fail "git bare-worktree ${action%%|*} differs from git ${action%%|*}-worktree"
    cmp "$first/result" "$tmp/eq/bwt_${action%%|*}/result" ||
        fail "git bwt ${action%%|*} differs from git ${action%%|*}-worktree"
done
git clone -q "$convert_src" "$tmp/bwt-convert"
run env PATH="$p_stub" git bwt convert "$tmp/bwt-convert"
expect_status "git bwt convert" 0
[ "$(git -C "$tmp/bwt-convert" rev-parse --is-bare-repository)" = true ]
[ "$(git -C "$tmp/bwt-convert/main" branch --show-current)" = main ]
: > "$WT_STUB_LOG"
ok "git bare-worktree <action> and git bwt <action> give the same result as the verb"

# --- Real Worktrunk: the samples parse ------------------------------------------

if [ "$real_mode" = 1 ]; then
    # Every commented setting in a sample, uncommented: wt must know each key.
    uncomment() {
        sed -E 's/^# (\[|[A-Za-z][A-Za-z.-]* *=)/\1/' "$1"
    }
    check_config_show() {
        label=$1
        shift
        run "$@"
        expect_status "$label" 0
        cat "$tmp/out" "$tmp/err" > "$tmp/show"
        expect_no_grep "$label" 'failed to parse' "$tmp/show"
        expect_no_grep "$label" 'nknown key' "$tmp/show"
        expect_no_grep "$label" 'nknown field' "$tmp/show"
    }
    checkout=$tmp/inferred/source/release-stable
    check_config_show "wt --config config.toml.example config show" \
        wt -C "$checkout" --config "$samples/config.toml.example" config show
    expect_grep "user sample" 'worktree-path = "{{ repo_path }}/../{{ branch | sanitize }}"' "$tmp/show"
    uncomment "$samples/config.toml.example" > "$tmp/user-uncommented.toml"
    check_config_show "user sample, uncommented" \
        wt -C "$checkout" --config "$tmp/user-uncommented.toml" config show
    run wt -C "$checkout" --config "$tmp/user-uncommented.toml" hook show
    expect_status "user sample hooks" 0
    expect_grep "user sample hooks" 'zoxide add {{ worktree_path }}' "$tmp/out"
    expect_grep "user sample hooks" 'zoxide remove {{ worktree_path }}' "$tmp/out"

    mkdir -p "$checkout/.config"
    cp "$samples/wt.toml.example" "$checkout/.config/wt.toml"
    check_config_show "project sample" \
        env -u WORKTRUNK_PROJECT_CONFIG_PATH wt -C "$checkout" config show
    expect_grep "project sample" "PROJECT CONFIG @ $checkout/.config/wt.toml" "$tmp/show"
    uncomment "$samples/wt.toml.example" > "$checkout/.config/wt.toml"
    check_config_show "project sample, uncommented" \
        env -u WORKTRUNK_PROJECT_CONFIG_PATH wt -C "$checkout" config show
    run env -u WORKTRUNK_PROJECT_CONFIG_PATH wt -C "$checkout" hook show
    expect_status "project sample hooks" 0
    expect_grep "project sample hooks" 'mise trust' "$tmp/out"
    ok "real wt: both samples parse, commented and uncommented, and the project file is read from the worktree"
fi

# --- Docs: absolute links into bare-worktree/ resolve -----------------------------

# Every https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/...
# link in the README and docs/*.md (docs/plans/ is a frozen record and isn't
# scanned) and the Setup link in the preflight messages must name a file in
# the working tree, and any #anchor must match a heading in it. GitHub's
# slugs: lowercase, punctuation dropped, spaces to -, then -1, -2 for repeats.
prefix=https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/
slugs() {
    awk '
        /^[ \t]*(```|~~~)/ { fence = !fence; next }
        fence || !/^#+[ \t]/ { next }
        {
            s = $0
            sub(/^#+[ \t]+/, "", s)
            sub(/[ \t#]+$/, "", s)
            gsub(/\]\([^)]*\)/, "", s)
            s = tolower(s)
            gsub(/[^a-z0-9 _-]/, "", s)
            gsub(/ /, "-", s)
            n = seen[s]++
            print (n ? s "-" n : s)
        }
    ' "$1"
}
# links <file>: "<file> <link>" for each link, trailing punctuation dropped.
links() {
    grep -o "${prefix}[^] )>\"'\`]*" | sed -e 's/[.,;:]*$//' -e "s|^|$1 |"
}
if [ ! -d "$samples/docs" ] || [ ! -f "$samples/README.md" ]; then
    echo "SKIP: docs link check (bare-worktree/README.md or docs/ not written yet)"
else
    : > "$tmp/links"
    for doc in "$samples/README.md" "$samples"/docs/*.md; do
        # Fenced blocks and inline code hold examples, not links.
        # shellcheck disable=SC2016 # the backticks are literal
        awk '/^[ \t]*(```|~~~)/ { fence = !fence; next } !fence' "$doc" |
            sed 's/`[^`]*`//g' | links "${doc#"$samples"/}" >> "$tmp/links" || true
    done
    for script in "$samples"/git-*; do
        links "${script#"$samples"/}" < "$script" >> "$tmp/links" || true
    done
    [ -s "$tmp/links" ] || fail "docs link check found no links"
    checked=0
    while read -r from link; do
        target=${link#"$prefix"}
        target=${target%%#*}
        [ -e "$samples/$target" ] || fail "$from: link to a missing file: $link"
        case $link in
            *'#'*)
                anchor=${link#*#}
                slugs "$samples/$target" | grep -Fxq -- "$anchor" ||
                    fail "$from: no heading for #$anchor in $target"
                ;;
        esac
        checked=$((checked + 1))
    done < "$tmp/links"
    ok "docs: all $checked absolute links into bare-worktree/ resolve to a file (and heading)"

    if [ -f "$samples/docs/usage.md" ]; then
        for line in 'git clone-worktree <repository> [directory]' \
            'git init-worktree <directory> [--branch <name>]' \
            'git convert-worktree [path] [--dry-run]' \
            'git bare-worktree <clone|convert|init|switch> [args...]' \
            'git bare-worktree config-example [--project]'; do
            grep -Fq -- "$line" "$samples/docs/usage.md" ||
                fail "docs/usage.md does not quote the usage line: $line"
        done
        ok "docs: usage.md quotes every usage line"
    fi
fi

echo "bare-worktree tests passed ($passes checks)"
