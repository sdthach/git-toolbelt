load helpers

prepare_sync () {
    export SYNC_LOG="$BATS_TEST_TMPDIR/calls"
    export GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary"
    : > "$SYNC_LOG"
    : > "$GITHUB_STEP_SUMMARY"
    echo aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa > .upstream-sync-base
    awk '
        /^        run: \|$/ { copying = 1; next }
        copying { sub(/^          /, ""); print }
    ' "$BATS_TEST_DIRNAME/../.github/workflows/upstream-sync.yml" > sync.bash

    mkdir bin
    cat > bin/gh <<'EOF'
#!/bin/sh
printf 'gh %s\n' "$*" >> "$SYNC_LOG"
case "$1 $2" in
    'repo view') printf '%s\n' "$SYNC_ISSUES_ENABLED";;
    'pr list') echo 0;;
    'issue list')
        [ "$SYNC_ISSUES_ENABLED" = true ] || exit 99
        echo 0
        ;;
    'pr create') echo 'https://example.com/pull/1';;
    'issue create')
        [ "$SYNC_ISSUES_ENABLED" = true ] || exit 99
        echo 'https://example.com/issues/1'
        ;;
    *) exit 98;;
esac
EOF
    cat > bin/git <<'EOF'
#!/bin/sh
printf 'git %s\n' "$*" >> "$SYNC_LOG"
case "$1" in
    rev-parse) echo bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb;;
    rev-list) echo 1;;
    ls-remote) exit 2;;
    diff)
        case "$2" in
            --binary) echo patch;;
            --name-only) echo git-modified;;
        esac
        ;;
    apply) cat >/dev/null; exit "${SYNC_CONFLICT:-0}";;
    log) echo '- bbbbbbb upstream change';;
esac
exit 0
EOF
    chmod +x bin/gh bin/git
    PATH="$PWD/bin:$PATH"
    export PATH
}

@test "clean upstream sync opens a PR when Issues are disabled" {
    prepare_sync
    export SYNC_ISSUES_ENABLED=false

    run bash sync.bash

    [ "$status" -eq 0 ]
    grep -q '^git push ' "$SYNC_LOG"
    grep -q '^gh pr create ' "$SYNC_LOG"
    ! grep -q '^gh issue ' "$SYNC_LOG"
    [ "$(cat .upstream-sync-base)" = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ]
}

@test "clean upstream sync still opens a PR when Issues are enabled" {
    prepare_sync
    export SYNC_ISSUES_ENABLED=true

    run bash sync.bash

    [ "$status" -eq 0 ]
    grep -q '^gh issue list ' "$SYNC_LOG"
    grep -q '^gh pr create ' "$SYNC_LOG"
}

@test "conflicting upstream sync reports manual steps when Issues are disabled" {
    prepare_sync
    export SYNC_ISSUES_ENABLED=false SYNC_CONFLICT=1

    run bash sync.bash

    [ "$status" -eq 1 ]
    grep -q 'git-modified' "$GITHUB_STEP_SUMMARY"
    grep -q 'Sync by hand' "$GITHUB_STEP_SUMMARY"
    ! grep -q '^git push ' "$SYNC_LOG"
    ! grep -q '^gh pr create ' "$SYNC_LOG"
    ! grep -q '^gh issue ' "$SYNC_LOG"
    [ "$(cat .upstream-sync-base)" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ]
}

@test "conflicting upstream sync opens an issue when Issues are enabled" {
    prepare_sync
    export SYNC_ISSUES_ENABLED=true SYNC_CONFLICT=1

    run bash sync.bash

    [ "$status" -eq 0 ]
    grep -q '^gh issue create ' "$SYNC_LOG"
    ! grep -q '^git push ' "$SYNC_LOG"
    ! grep -q '^gh pr create ' "$SYNC_LOG"
}
