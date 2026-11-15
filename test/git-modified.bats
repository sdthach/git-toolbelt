load helpers

@test "prints names starting with - or + as ./-name and ./+name" {
    init_repo
    touch -- -rf +42 normal.txt

    run git modified

    [ "$status" -eq 0 ]
    assert_output - <<EOF
./+42
./-rf
normal.txt
EOF
}

@test "prefixes ./ relative to the current directory" {
    init_repo
    mkdir src
    touch -- -rf src/-x src/+y
    git add -A
    cd src

    run git modified -i

    [ "$status" -eq 0 ]
    assert_output - <<EOF
../-rf
./+y
./-x
EOF
}

@test "prints names with spaces, quotes and backslashes as-is" {
    init_repo
    touch -- ' lead.txt' 'with space.txt' 'quo"te.txt' 'back\tab.txt' 'a -> b.txt'

    run git modified

    [ "$status" -eq 0 ]
    assert_output - <<'EOF'
 lead.txt
a -> b.txt
back\tab.txt
quo"te.txt
with space.txt
EOF
}

@test "prints only the new name of a renamed file" {
    init_repo
    echo hi > 'old name.txt'
    git add -A
    git commit -q -m "Add file"
    git mv 'old name.txt' 'new name.txt'

    run git modified -i

    [ "$status" -eq 0 ]
    assert_output "new name.txt"
}

@test "prints names with spaces, quotes and backslashes as-is for a commit" {
    init_repo
    touch -- ' lead.txt' 'with space.txt' 'quo"te.txt' 'back\tab.txt'
    git add -A
    git commit -q -m "Add files"

    run git modified HEAD

    [ "$status" -eq 0 ]
    assert_output - <<'EOF'
 lead.txt
back\tab.txt
quo"te.txt
with space.txt
EOF
}

@test "lists add/add conflicts and detects them in quiet mode" {
    init_repo
    git switch -q -c other
    echo other > both-added.txt
    git add -A
    git commit -q -m "Add file on other"
    git switch -q main
    echo main > both-added.txt
    git add -A
    git commit -q -m "Add file on main"
    run git merge other
    [ "$status" -eq 1 ]

    run git modified -u
    [ "$status" -eq 0 ]
    assert_output "both-added.txt"

    run git modified -uq
    [ "$status" -eq 0 ]
    assert_output ""
}

@test "skips newline filenames without creating fake status entries" {
    init_repo
    touch -- $'b\n?? injected.txt' zzz.txt

    for mode in '' -i; do
        run --separate-stderr git modified $mode
        [ "$status" -eq 0 ]
        assert_output "zzz.txt"
        [ "$stderr" = "git modified: skipping a filename that contains a newline" ]
    done

    git add -A
    run --separate-stderr git modified -i
    [ "$status" -eq 0 ]
    assert_output "zzz.txt"
    [ "$stderr" = "git modified: skipping a filename that contains a newline" ]
}

@test "skips newline filenames in commits" {
    init_repo
    touch -- $'b\n?? injected.txt' zzz.txt
    git add -A
    git commit -q -m "Add files"

    run --separate-stderr git modified HEAD
    [ "$status" -eq 0 ]
    assert_output "zzz.txt"
    [ "$stderr" = "git modified: skipping a filename that contains a newline" ]
}

@test "keeps rename records intact when either name contains a newline" {
    init_repo
    echo source > $'source\n?? injected.txt'
    echo other > old.txt
    git add -A
    git commit -q -m "Add rename sources"
    git mv -- $'source\n?? injected.txt' destination.txt
    git mv -- old.txt $'new\n?? injected.txt'

    run --separate-stderr git modified -i
    [ "$status" -eq 0 ]
    assert_output "destination.txt"
    [ "$stderr" = "git modified: skipping a filename that contains a newline" ]

    git commit -q -m "Rename files"
    run --separate-stderr git modified HEAD
    [ "$status" -eq 0 ]
    assert_output "destination.txt"
    [ "$stderr" = "git modified: skipping a filename that contains a newline" ]
}

@test "reports no printable changes when only a newline filename remains" {
    init_repo
    touch -- $'b\n?? injected.txt'

    run --separate-stderr git modified
    [ "$status" -eq 1 ]
    assert_output ""
    [ "$stderr" = "git modified: skipping a filename that contains a newline" ]

    run git modified -q
    [ "$status" -eq 1 ]
    assert_output ""
}
