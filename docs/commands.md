# Command reference

Full reference for every `git-*` script in this toolbelt. Commands marked with ⭐️ are personal favorites, used almost every day. For the `g`+verb shortcut executables (`getch`, `gadd`, etc.), see [portmanteaus.md](portmanteaus.md) instead — this page only covers the `git-*` scripts.

Back to the [README](../README.md).

## Everyday helpful commands

- ⭐️ [git-cleanup](#git-cleanup)
- [git-current-branch](#git-current-branch)
- [git-main-branch](#git-main-branch)
- ⭐️ [git-fixup](#git-fixup)
- [git-autofixup](#git-autofixup)
- ⭐️ [git-fixup-with](#git-fixup-with)
- ⭐️ [git-active-branches](#git-local-branches--git-remote-branches--git-active-branches)
- ⭐️ [git-diff-since](#git-diff-since)
- [git-local-branches](#git-local-branches--git-remote-branches--git-active-branches)
- [git-local-commits](#git-local-commits--git-has-local-commits)
- [git-merged / git-unmerged / git-merge-status](#git-merged--git-unmerged--git-merge-status)
- [git-branches-containing](#git-branches-containing)
- [git-recent-branches](#git-recent-branches)
- [git-remote-branches](#git-local-branches--git-remote-branches--git-active-branches)
- [git-remote-tracking-branch](#git-remote-tracking-branch)
- [git-root](#git-root)
- [git-initial-commit](#git-initial-commit)
- ⭐️ [git-sha](#git-sha)
- [git-stage-all](#git-stage-all)
- [git-unstage-all](#git-unstage-all)
- [git-update-all](#git-update-all)
- [git-workon](#git-workon)
- ⭐️ [git-modified](#git-modified)
- ⭐️ [git-modified-since](#git-modified-since)
- [git-last-commit-to-file](#git-last-commit-to-file)
- ⭐️ [git-separator](#git-separator)
- ⭐️ [git-spinoff](#git-spinoff)
- ⭐️ [git-wip](#git-wip)

## Statistics

- [git-committer-info](#git-committer-info)

## Commands to help novices out

- [git-drop-local-changes](#git-drop-local-changes)
- [git-stash-everything](#git-stash-everything)
- ⭐️ [git-push-current](#git-push-current)
- [git-undo-commit](#git-undo-commit)
- [git-undo-merge](#git-undo-merge)
- [git-trash](#git-trash)

## Commands that simplify scripting

These commands typically only return exit codes and have no output.

- [git-is-repo](#git-is-repo)
- [git-is-headless](#git-is-headless)
- [git-has-local-changes / git-is-clean / git-is-dirty](#git-has-local-changes--git-is-clean--git-is-dirty)
- [git-has-local-commits](#git-local-commits--git-has-local-commits)
- [git-contains / git-is-ancestor](#git-contains--git-is-ancestor)
- [git-local-branch-exists / git-remote-branch-exists / git-tag-exists](#git-local-branch-exists--git-remote-branch-exists--git-tag-exists)
- [git-relative-path](#git-relative-path)

## Advanced usage

- [git-skip / git-unskip / git-show-skipped](#git-skip--git-unskip--git-show-skipped)
- [git-commit-to](#git-commit-to)
- [git-cherry-pick-to](#git-cherry-pick-to)
- ⭐️ [git-delouse](#git-delouse)
- ⭐️ [git-shatter-by-file](#git-shatter-by-file)
- ⭐️ [git-cleave](#git-cleave)
- [git-edit-author-dates](#git-edit-author-dates)
- [git-amend-date](#git-amend-date)
- [git-sync-commit-date](#git-sync-commit-date)
- [git-conflicts](#git-conflicts)
- [git-merges-cleanly](#git-merges-cleanly)
- [git-force-checkout (planned)](#git-force-checkout-planned)

---

### git current-branch

Returns the name of the current branch, if any. Why doesn't this come with git?

```console
$ git current-branch
main
```

Alias to `git rev-parse --abbrev-ref HEAD`.

### git main-branch

Returns the name of the default main branch for this repository. Historically `master`, but could also be `main` if you've changed the default branch name. Since there's no way of reliably telling what the default branch name is for a repo, this script will probe for the existence of local branches named either `main` or `master`. The first one found is used.

```console
$ git main-branch
main
```

### git sha

Returns the SHA value for the specified object, or the current branch head, if nothing is provided.

```console
$ git sha <some-object>
```

Typical example:

```console
$ git sha HEAD
f688d7543c5d52f5f78b3db1b0dd1616059299a4
$ git sha -s HEAD
f688d75
```

Shows the commit SHA for the latest commit.

### git modified

Returns a list of locally modified files. In contrast to git status, it does not include any detailed file status, and never includes non-existing files.

This makes it ideal for the following use-case:

```console
$ vim (git modified)
```

If you want to locally modified files that are already staged, too, use:

```console
$ vim (git modified -i)
```

To restrict the result to one or more paths, pass pathspecs after `--`. For example, to list locally modified files inside the current directory only:

```console
$ git modified -- .
```

### git modified-since

Like git-modified, but for printing a list of files that have been modified since main (or whatever commit specified). In contrast to git status, it does not include any detailed file status, and never includes non-existing files.

Opens all files modified on your branch (since you branched off `main`).

```console
$ vim (git modified-since)
```

### git last-commit-to-file

Returns the SHA of the commit that last touched the given file(s). If multiple files are given, returns the SHA that most recently changed *any* of them.

```console
$ git last-commit-to-file somefile.txt
```

Used internally by `git-autofixup` to find which commit to fixup against.

### git autofixup

Looks at your currently staged files, figures out which commit last touched each of them (via `git-last-commit-to-file`), and runs `git commit --fixup <sha>` against that commit automatically — no need to remember or look up the SHA yourself.

```console
$ git add somefile.txt
$ git autofixup
```

Errors out if no staged files have been previously committed, or if it can't determine a single commit that touched them.

### git separator

Adds a commit with a message of only ---'s, so that it visually separates commits in the history. This is incredibly useful when doing more complex rebase operations. (They should be used as a temporary measure, and ideally taken out of the history again when done rebasing.)

### git spinoff

Inspired by Magit's `spinoff` command. Creates and checks out a new branch starting at and tracking the current branch. That branch in turn is reset to the last commit it shares with its upstream. If the current branch has no upstream or no unpushed commits, then the new branch is created anyway and the previously current branch is not touched.

This is useful to create a feature branch after work has already began on the old branch (likely but not necessarily `main`).

### git push-current

Pushed the current branch out to `origin`, and makes sure to setup tracking of the remote branch. Shorthand for `git push -u origin <current-branch>`.

Accepts options, too, so you can use

```console
$ git push-current -f
```

to force-push.

### git is-headless

Tests if `HEAD` is pointing to a branch head, or is detached.

### git diff-since

Shows the differences made on the current branch, compared to the main branch (or the given branch).

### git local-branches / git remote-branches / git active-branches

Returns a list of local or remote branches, but contrary to Git's default commands for this, returns them machine-processable. In the case of remote branches, can be asked to return only the branches in a specific remote.

For `git active-branches`, a branch is deemed "active" if its head points to a commit authored in the last 3 weeks, by default. An arbitrary date can be specified using either `git active-branches -s <date>` or `-a <date>` (mnemonic: "since" or "after"), using any date format [supported by `git log`][gitlog].

### git local-branch-exists / git remote-branch-exists / git tag-exists

Tests if the given local branch, remote branch, or tag exists.

### git relative-path

Resolves one or more paths (relative to the repo root) to paths relative to the current working directory, using GNU `realpath`/`grealpath` under the hood. Used internally by `git-autofixup` to turn `git diff` output back into paths you can pass to other commands from wherever you're standing in the tree.

```console
$ cd sub/dir
$ git relative-path some/file/at/root.txt
```

Requires GNU coreutils; see [docs/install.md](install.md) for the macOS note.

### git recent-branches

Returns a list of local branches, ordered by recency:

    $ git recent-branches
    foo
    main
    bar
    qux

### git remote-tracking-branch

Print the name of the remote tracking branch of the current or given local branch name, if one exists. Errors otherwise.

### git local-commits / git has-local-commits

Returns a list of commits that are still in your local repo, but haven't been pushed to `origin`. `git has-local-commits` is the scriptable equivalent that only returns an exit code if such commits exist.

### git contains / git is-ancestor

Tests if X is merged into Y:

    $ git contains X Y  # does X contain Y?
    $ git is-ancestor X Y  # is X an ancestor of Y?

**CAVEAT:** Even though they might look like opposites, `X contains Y` does not mean `not (X is-ancestor Y)`, since (1) X and Y can point to the same commit, or the branches may have no common history and thus be unrelated completely.

### git stage-all

Mimics the index / staging area to match the working tree exactly. Adds files, removes files, etc.

Alias to `git add --all`.

### git unstage-all

Unstages everything. Leaves the working tree intact.

Alias to `git reset HEAD`.

### git undo-merge

Ever created a merge accidentally, or decided that you didn't want to merge after all? You can undo the last merge using `git undo-merge`.

### git undo-commit

Ever committed too soon, or by accident? Or on the wrong branch? You can now undo your last commit and you won't lose any data. All the changes in the commit will be staged (like right before the commit) and the commit itself is gone.

### git cleanup

Deletes all branches that have already been merged into the main branch. Keeps other branches lying around. Removes branches both locally and in the origin remote. Will be most conservative with deletions.

### git fixup

Amend all local staged changes into the last commit. Ideal for fixing typo's, when you don't want to re-edit the commit message.

    $ git commit -m "Something cool."
    $ vim somefile.txt  # fix typo
    $ git add somefile.txt
    $ git fixup  # merge this little change back into the last commit

### git fixup-with

Interactively lets you pick a commit to fixup with. (Uses `fzf` for the interactive picking. Use `brew install fzf` to install this tool separately.) Use `-r` to trigger an interactive rebase right afterwards.

### git workon

Convenience command for quickly switching to a branch `<name>`. If such local branch does not exist, but there is a remote branch named `origin/<name>`, then a local branch is created and the remote is tracked.

### git delouse

Say you want to rebuild your last commit, but want to keep the commit message. git delouse empties the last commit on the current branch and places all changes back into the working tree.

Since the commit remains in history, you can now rebuild the commit by "git amend"'ing or "git fixup"'ing, instead of making new commits.

### git shatter-by-file

Splits the last commit into N+1 commits, where N is the number of files in the last commit. The first commit is an empty commit with the original commit message and author details, and the following commits add (or delete) one file each, keeping the subject line of the original commit message.

After running `git shatter-by-file`, you'll typically want to run `git rebase --interactive` to start fixing up changes to files, etc. For that purpose, the original commit message is kept in there (in the empty first commit), so make sure to use it.

### git cleave

Splits the last commit into 2 or more commits. Takes one or more regex values (which are fed to `grep -Ee`), and will split the last commit by file paths matching each of the regexes.

For example:

    $ git cleave client/ server/

Will split the last commit into 2 (or 3) commits. The first one will contain all the files containing `client/`, the second will contain all the files matching `server/`. If there are files that don't match either of those, then a 3rd commit will be made with the "remainder".

Another example:

    $ git cleave '.*\.js$'

This will split off all Javascript files from a commit.

### git commit-to

Ever been on a branch and really wanted to quickly commit a change to a different branch? Given that this is possible without merge conflicts, git commit-to will allow you to do so, without checking out the branch necessarily.

    $ git branch
      main
    * mybranch
    $ git status
    M foo.txt
    M bar.txt
    $ git add foo.txt
    $ git commit-to main -m "Add foo to main."
    $ git add bar.txt
    $ git commit -m "Add bar to mybranch."

### git cherry-pick-to

Every been on a branch, just made a commit, but really want that commit available on other branches as well? You can now cherry-pick this commit to any branch, staying on the current branch. (Given the change won't lead to a merge conflict.)

    $ git branch
      main
    * mybranch
    $ git add foo.txt
    $ git commit -m "Really useful thing."
    $ git cherry-pick-to main HEAD
    $ git branch  # did not switch branches
      main
    * mybranch

### git is-repo

Helper function that determines whether the current directory has a Git repo associated to it.

### git root

`git root` prints the root location of the working tree.

    $ cd /path/to/worktree
    $ cd some/dir/in/worktree
    $ pwd
    /path/to/worktree/some/project/dir
    $ git root
    /path/to/worktree

### git initial-commit

`git initial-commit` prints the initial commit for the repo.

    $ git initial-commit
    48c94a6a29e9e52ab63ce0fab578101ddc56a04f

### git has-local-changes / git is-clean / git is-dirty

Helper function that determines whether there are local changes in the working tree, by returning a 0 (local changes) or 1 (no local changes) exit code.

### git drop-local-changes

Don't care about your local working copy's state and really want to revert back to whatever is recorded in the history? git drop-local-changes lets you do this.

This covers aborting rebases, undoing partial merges, resetting the index and removing any unknown local files from the work tree. Anything that is already committed remains safe.

### git stash-everything

The stash behaviour you (probably) always wanted. This actually stashes everything what's in your index, in your working tree, and even stashes away your untracked files, leaving a totally clean working tree.

Using "git stash pop" will recover all changes, including index state, locally modified files, and untracked files.

### git trash

Nukes your working tree back to the state of the last commit — no questions asked. Internally it stages everything, commits it as `Trash`, then hard-resets one commit back, so the discarded state briefly exists in the reflog if you change your mind. If the working tree is already clean, it's a no-op.

    $ git trash
    Nothing to trash.

### git update-all

Updates all local branch heads to the remote's equivalent. This is the same as checking out all local branches one-by-one and pulling the latest upstream changes. Will only update if a pull succeeds cleanly (i.e. is a fast-forward pull).

### git-merged / git-unmerged / git-merge-status

This trio of subcommands makes it easy to inspect merge status of local branches. Use them to check whether any local branches have or haven't been merged into the target branch (defaults to `main`).

git-merge-status is a useful command that presents both lists in a single overview (not for machine processing).

### git-branches-containing

This command, "git branches-containing [<object>]" returns a list of branches which contain the specified '<object>' (defaults to 'HEAD').

git-branches-containing is useful to see if a branch has been merged, and, if so, which releases contain the feature/fix (if you use release branches).

### git-committer-info

Shows contribution stats for the given committer, like "most productive day", "most productive hour", "average commit size", etc.

### git force-checkout (planned)

Not yet implemented — there is no `git-force-checkout` script in this repo today. Kept here as a note of intent from upstream: the idea is a `git checkout` that gives up safety checks entirely and discards conflicting local changes, similar in spirit to `git-drop-local-changes` but scoped to a single checkout operation. Track upstream if this ever lands, or open an issue if you want it built.

### git conflicts

Generates a summary for all local branches that will merge uncleanly — i.e. will lead to merge conflicts later on.

    $ git branch
      develop
    * mybranch
      main
      other-branch
    $ git conflicts
    develop... merges cleanly
    main...  merges cleanly
    other-branch... CONFLICTS AHEAD

### git merges-cleanly

The single-branch building block behind `git-conflicts`: performs a temporary merge against the given branch (then aborts or undoes it) and reports success or failure through the exit code alone. Pass `-l` to also list the conflicting files.

```console
$ git merges-cleanly main
$ git merges-cleanly -l main
```

### git skip / git unskip / git show-skipped

Git supports marking files "skip worktree", meaning any change in the file locally will not be shown in status reports, or be added when you stage all files. This feature can be useful to toggle some switches locally, or experiment with different settings, without running the risk of accidentally committing this local data (that should remain untouched in the repo).

Notice that status reports won't show these files anymore, so it's also easily to lose track of these marked assumptions, and you probably run into weird issues if you don't remember this. (This is the reason why these scripts are in the "advanced" category.)

Basic usage:

    $ git status
     M foo.txt
     M bar.txt
     M qux.txt
    $ git skip foo.txt
    $ git status
     M bar.txt
     M qux.txt
    $ git show-skipped
    foo.txt
    $ git commit -am 'Commit everything.'
    $ git status
    nothing to commit, working directory clean
    $ git is-clean && echo "clean" || echo "not clean"
    not clean
    $ git unskip -a
    $ git status
     M foo.txt

As you can see, `git-is-clean` is aware of any lurking "skipped" files, and won't report a clean working tree, as these assumed unchanged files often block the ability to check out different branches.

### git edit-author-dates

Opens an interactive rebase with lines pre-populated with each commit's current author date. Edit the dates, save, and the rebase applies them.

```console
$ git edit-author-dates
```

You'll see something like:

```
pick abc123 Some commit
exec git amend-date 2026-04-01T08:47:29+02:00
pick def456 Another commit
exec git amend-date 2026-04-01T09:17:31+02:00
```

By default, the base is the merge-base with the upstream tracking branch. You can pass an explicit base:

```console
$ git edit-author-dates HEAD~5
```

### git amend-date

Amends `HEAD` to set both the author date and the committer date to the given strict ISO 8601 timestamp (`YYYY-MM-DDTHH:MM:SS±HH:MM` or `...Z`), preserving the author name and email. This is the plumbing command that `git-edit-author-dates` generates `exec` lines for during its rebase — you normally won't call it directly.

```console
$ git amend-date 2026-04-01T08:47:29+02:00
```

### git sync-commit-date

Rewrites the `HEAD` commit so its committer date matches its author date (useful after a rebase or amend shuffled the committer date out of sync). Requires a clean working tree. Prompts for confirmation unless `-f` is given; pass `-q` to suppress the "created ..." summary.

```console
$ git sync-commit-date
$ git sync-commit-date -fq
```

### git wip

Commits all local changes under a commit message of "WIP". Great for quickly creating "savepoint" commits. If there is a mix of staged changes, and unstaged changes, and new files, will commit each of these as a separate commit, all titled "WIP". Effectively, running `git-wip` once will potentially lead to anywhere between 0 and 3 "WIP" commits being created.

[gitlog]: https://git-scm.com/book/en/v2/Git-Basics-Viewing-the-Commit-History#_limiting_log_output
