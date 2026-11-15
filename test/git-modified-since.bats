load helpers

@test "prints names starting with - or + as ./-name and ./+name" {
    init_repo
    git switch -q -c feature
    touch -- -rf +42 normal.txt
    git add -A
    git commit -q -m "Add files"

    run git modified-since

    [ "$status" -eq 0 ]
    assert_output - <<EOF
./+42
./-rf
normal.txt
EOF
}

@test "prints names with spaces, quotes and backslashes as-is" {
    init_repo
    git switch -q -c feature
    touch -- ' lead.txt' 'with space.txt' 'quo"te.txt' 'back\tab.txt'
    git add -A
    git commit -q -m "Add files"

    run git modified-since

    [ "$status" -eq 0 ]
    assert_output - <<'EOF'
 lead.txt
back\tab.txt
quo"te.txt
with space.txt
EOF
}

@test "skips newline filenames and keeps quiet mode silent" {
    init_repo
    git switch -q -c feature
    touch -- $'b\n?? injected.txt' zzz.txt
    git add -A
    git commit -q -m "Add files"

    run --separate-stderr git modified-since
    [ "$status" -eq 0 ]
    assert_output "zzz.txt"
    [ "$stderr" = "git modified-since: skipping a filename that contains a newline" ]

    run git modified-since -q
    [ "$status" -eq 0 ]
    assert_output ""

    git rm -q zzz.txt
    git commit -q -m "Remove the printable filename"
    run --separate-stderr git modified-since
    [ "$status" -eq 1 ]
    assert_output ""
    [ "$stderr" = "git modified-since: skipping a filename that contains a newline" ]

    run git modified-since -q
    [ "$status" -eq 1 ]
    assert_output ""
}
