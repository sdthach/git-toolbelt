# Bare-worktree: decisions and divergences after the plan

Back to the [bare-worktree README](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/README.md).

See also the [plan](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-plan.md) · [decisions](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/decisions.md)

<!--
Entry formats (newest last):

### YYYY-MM-DD: <title>
- **Decision:**
- **Why:**
- **Affects:** <files or docs changed>

### YYYY-MM-DD: <title>
- **Plan said:** <quote, with the plan section>
- **Did instead:**
- **Why:** <what was found, with evidence such as a command and its output>
- **Affects:**
-->

## Decisions made after the plan

These include the plan's open checks, now resolved.

### 2026-11-12: wt messages without shell integration

- **Decision:** `docs/usage.md` quotes what wt 0.81.0 prints (on stderr, exit 0) when it cannot change
  directory, and says that the `git-wt` hint is wrong for `git switch-worktree`. The three cases:
  - integration installed but not active in this shell:
    `▲ Worktree for <branch> @ '<path>', but cannot change directory — ran <wt binary>; shell integration wraps wt`
    then `↳ To change directory, run wt switch <branch>`;
  - integration not installed:
    `▲ Worktree for <branch> @ <path>, but cannot change directory — shell integration not installed`
    then `↳ To enable automatic cd, run wt config shell install`;
  - through `git switch-worktree <branch>`:
    `▲ Worktree for <branch> @ <path>, but cannot change directory — ran git wt; running through git prevents cd`
    then `↳ For automatic cd, invoke directly (with the -): git-wt`.
- **Why:** this was the plan's open check ("confirm what wt prints when shell integration isn't active").
  wt sees that it was started by git and assumes `git wt`. There is no `git-wt` command on Linux or macOS
  (only Worktrunk's Winget package installs one, on Windows), so the hint leads nowhere. The fix stays the
  documented one: `wt switch <branch>` or `cd`.
- **Affects:** `docs/usage.md` (Getting into a worktree), `docs/gotchas.md` (git switch-worktree does not
  cd), `docs/decisions.md` (5).

### 2026-11-12: zoxide remove and the post-remove hook

- **Decision:** `config.toml.example` keeps the `post-remove = "zoxide remove {{ worktree_path }}"` line.
- **Why:** this was the plan's open check. With zoxide 0.10, `zoxide remove` on a path that was added and
  then deleted exits 0. On a path zoxide never knew, it exits 1 with `path not found in database`; in a
  background `post-remove` hook that only lands in wt's log, so it is harmless.
- **Affects:** `config.toml.example`, the heredoc in `git-bare-worktree`.

### 2026-11-12: zoxide doctor warning

- **Decision:** `_ZO_DOCTOR` is not set anywhere, and the docs do not suggest it.
- **Why:** this was the plan's open check. With the documented order (zoxide init on the last line, after
  atuin, Worktrunk and the prompt), zoxide 0.10 prints no `detected a possible configuration issue`
  warning. Checked in a real pty: after bash-preexec installs on the first prompt, `PROMPT_COMMAND` still
  holds `__zoxide_hook`.
- **Affects:** `docs/gotchas.md` (Works with atuin).

### 2026-11-12: fzf Ctrl-R can be turned off alone

- **Decision:** the atuin section documents `FZF_CTRL_R_COMMAND=` (set to empty) before
  `eval "$(fzf --bash)"` as the way to get fzf's Ctrl-T and Alt-C without losing atuin's Ctrl-R. fzf's key
  bindings stay off by default.
- **Why:** this was the plan's open check. fzf 0.75's `fzf --bash` binds Ctrl-R only when
  `${FZF_CTRL_R_COMMAND-x}` is not empty, so an empty value skips Ctrl-R and nothing else.
- **Affects:** `docs/gotchas.md` (Works with atuin), `docs/decisions.md` (12).

### 2026-11-12: Tool versions used

- **Decision:** the tools come from mise: wt 0.81.0, fzf 0.75.0, zoxide 0.10.0. Every test ran on wt
  0.81.0.
- **Why:** the plan asked for the resolved versions to be recorded, because all later tests depend on
  them. The docs do not pin versions.
- **Affects:** nothing in the shipped files.

## Where the implementation diverged from the plan

### 2026-11-12: Convert with extensions.worktreeConfig

- **Plan said:** "`git config core.bare true`, and unset `core.worktree` if it's set" (step 3) and "Move
  `.git/config.worktree` there if it exists" (step 5), in "`git convert-worktree [path] [--dry-run]`".
- **Did instead:** when `extensions.worktreeConfig` is on, step 3 writes `core.bare = true` into
  `.git/config.worktree`. Step 5 copies that file to the new worktree's git dir, unsets `core.bare` in the
  copy, and rewrites the bare repo's file to hold only `core.bare = true`. Without `worktreeConfig`, the
  plain `git config core.bare true` and `mv` stay.
- **Why:** with `worktreeConfig` on, `core.bare = true` in the shared config applies to every worktree.
  After such a conversion, `git -C r/main rev-parse --is-bare-repository` printed `true`, and commands that
  need a work tree failed there with `fatal: this operation must be run in a work tree`.
- **Affects:** `git-convert-worktree` (steps 3 and 5, recovery output), `scripts/test-bare-worktree.sh`,
  `docs/architecture.md`.

### 2026-11-12: Init checks identity and branch name first

- **Plan said:** "Make an empty root commit ... If `user.name`/`user.email` are unset, git fails with its
  normal message." ("`git init-worktree`", step 5).
- **Did instead:** before creating anything, init checks the identity with `git var GIT_AUTHOR_IDENT` and
  `git var GIT_COMMITTER_IDENT`, and the branch name with `git check-ref-format --branch`. Either failure is
  a refusal (exit 1): `set user.name and user.email first; nothing was created`, or
  `'<name>' is not a valid branch name`.
- **Why:** in the plan's order, the commit failed after `<dir>/.git` and the worktree already existed, which
  left a half-made repo behind and broke the "refuse, changing nothing" rule the other refusals follow.
- **Affects:** `git-init-worktree`, `docs/usage.md`, `docs/architecture.md`.

### 2026-11-12: Four more convert refusals

- **Plan said:** "Refuse, changing nothing, if": a linked worktree, already bare, detached or unborn HEAD,
  an operation in progress, initialised submodules, sparse checkout ("`git convert-worktree`").
- **Did instead:** convert also refuses when:
  - the git dir is not `<top>/.git` (a separate git dir, or `core.worktree` pointing elsewhere);
  - HEAD is a symbolic ref to something other than a local branch;
  - a linked worktree is already registered at the target folder;
  - the stage folder `.convert-worktree.<pid>` already exists.
- **Why:** each of these would make a later step fail after files had moved, or move files to the wrong
  place. Refusing up front keeps the "changing nothing" promise.
- **Affects:** `git-convert-worktree`, `docs/usage.md`, `docs/architecture.md`, `docs/decisions.md` (9).

### 2026-11-12: Convert failure handling by step

- **Plan said:** "**On failure partway through:** stop and print exact recovery commands (where the files
  are, `git config core.bare false`, how to move them back). There is no automatic rollback."
- **Did instead:** recovery commands are printed for failures in steps 2 to 7, tailored to the step
  reached. A failing `git worktree repair` in step 7 only warns, with the command to rerun. A failure from
  step 8 on prints `stopped at step <n>, after the conversion itself was done.` and no restore commands.
- **Why:** the plan only covered failures while files are moving. From step 8 on, the conversion is
  complete and only the remote setup is left; restore commands would undo good work. A failed repair leaves
  the conversion correct and only the nested worktrees' records stale, which a rerun fixes.
- **Affects:** `git-convert-worktree`, `docs/usage.md`, `docs/architecture.md`, `docs/decisions.md` (9).
- **Later:** changed again after the review: a stop from step 7 on is reported as done, and recovery never
  prunes. See [Recovery without prune](#2026-11-12-recovery-without-prune).

### 2026-11-12: Relocate hint only when needed

- **Plan said:** "Run the final `wt switch` with its warning behaviour, then print a hint:
  `wt step relocate --dry-run` can move linked worktrees that sit outside the layout." (convert, step 9).
- **Did instead:** the `Hint:` line is printed only when the repo has other linked worktrees, and before
  the `Checkout:`/`Next:` lines, after a `Converted <repo>: ...` line.
- **Why:** with no other worktrees there is nothing to relocate. Printing it before `Checkout:`/`Next:`
  keeps those as the last lines, as the shared output rule says.
- **Affects:** `git-convert-worktree`, `docs/usage.md`, `docs/architecture.md`.
- **Later:** after the review the hint counts only worktrees outside the repo. See
  [Message accuracy and movability precheck](#2026-11-12-message-accuracy-and-movability-precheck).

### 2026-11-12: Clone runs the preflight before the destination checks

- **Plan said:** `git-clone-worktree` "takes over the body of the staged `wt-clone`", which checked the
  destination before looking for `wt`.
- **Did instead:** after the argument checks, clone runs the preflight first, then the destination checks.
- **Why:** it matches the other commands and the shared rule "Preflight, before touching anything", so a
  missing `wt` is reported the same way everywhere.
- **Affects:** `git-clone-worktree`, `docs/usage.md`, `docs/architecture.md`.

### 2026-11-12: Sample config layout

- **Plan said:** `config.toml.example` holds "the bare-layout `worktree-path` with an explanation, a
  commented `[projects]` per-repo override, a commented zoxide hook block" ("`bare-worktree/` folder").
- **Did instead:** the zoxide hooks sit at the top level, before any table, with a note to keep every
  top-level key above the first table. The `[projects]` example shows a sibling layout
  (`{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}`) for a repo that stays a normal clone.
- **Why:** in TOML a key after a `[table]` header belongs to that table, so hooks placed after
  `[projects]` would stop being user hooks. A `[projects]` example that repeats the global bare layout
  would show nothing; the useful override is the one for a repo that is not converted.
- **Affects:** `config.toml.example`, the heredoc in `git-bare-worktree`.

### 2026-11-12: Test isolation and failure injection

- **Plan said:** "the test builds a throwaway bin directory ... and sets `PATH` to that directory alone"
  ("Tests: `scripts/test-bare-worktree.sh`").
- **Did instead:**
  - the tests also point `HOME` and `XDG_CONFIG_HOME` into the throwaway folder, turn off git's system
    config (`GIT_CONFIG_NOSYSTEM`) and give zoxide a scratch data folder;
  - failure-injection cases call `git-convert-worktree` by its file name, not as `git convert-worktree`;
  - the real-wt run also checks both samples with every commented setting uncommented.
- **Why:** the isolation keeps a developer's own git, wt or zoxide config from changing the results. git puts
  its exec-path, which holds another git, ahead of `PATH` for subcommands, so a failing stub on `PATH` was
  never reached through `git convert-worktree`. The uncommented check proves every commented key in the
  samples is one wt accepts.
- **Affects:** `scripts/test-bare-worktree.sh`, `docs/architecture.md` (Tests).

### 2026-11-12: Undo recipe must not prune before repair

- **Plan said:** `docs/usage.md` has a manual convert recipe "including how to undo it and the
  nested-worktree repair" ("Docs").
- **Did instead:** the undo recipe deletes `.git/worktrees/<branch-dir>` directly, runs
  `git worktree repair` for nested worktrees, and warns not to run `git worktree prune` first.
- **Why:** in a scratch repo, `git worktree prune` before the repair deleted the nested worktree's record,
  because its recorded path still pointed into the removed `main/`. Afterwards
  `git -C .claude/worktrees/nested status` failed with
  `fatal: gitfile does not point to a valid repository: <repo>/.claude/worktrees/nested/.git`. With the
  record removed directly and the repair run, the nested worktree worked and `git status --porcelain=v2`
  matched the state before the conversion.
- **Affects:** `docs/usage.md` (Undo a conversion).

### 2026-11-12: Plan copy edits

- **Plan said:** the plan copy keeps "the design sections verbatim", removes the other repo names in
  "Current state", and its check is a grep that "finds nothing".
- **Did instead:**
  - the plan's own "check before commit" line was reworded to describe the grep, not quote it;
  - the "Current state" line naming other repos became "Other repos on the machine already use the layout.";
  - the title is the header template's, and the original title is kept on an "Original title:" line.
- **Why:** the quoted grep pattern matched itself, so the check could never pass. The other two keep the
  facts without the names.
- **Affects:** `docs/plans/2026-11-12-bare-worktree-plan.md`.

### 2026-11-12: Homebrew formula test

- **Plan said:** in `test do`, "`git bare-worktree config-example` succeeds" and "with `PATH` set
  explicitly to `bin` and the system dirs (no wt), `git clone-worktree` fails with the preflight message"
  ("Homebrew").
- **Did instead:** the test checks that the `config-example` output contains `worktree-path`, and the no-wt
  `PATH` is `bin:/usr/bin:/bin`.
- **Why:** a command that prints nothing would also "succeed"; matching `worktree-path` proves the sample
  was printed. `bin:/usr/bin:/bin` is the concrete form of "bin and the system dirs"; it leaves out
  Homebrew's own `bin` folder, where an installed wt would be found.
- **Affects:** `packaging/git-toolbelt.rb`.

### Review findings

An independent review of the implementation found the problems below; each entry is one finding. Every fix
has a regression test in `scripts/test-bare-worktree.sh` that fails without it, except the step-4 backstop
in the first entry and the atomic `config.worktree` write in the last, which were checked by hand.

### 2026-11-12: Repository variables are cleared or checked

- **Plan said:** nothing about `GIT_DIR` and the other repository-location variables. Convert's path "is
  resolved with `git -C <path> rev-parse --show-toplevel`" ("`git convert-worktree [path] [--dry-run]`"),
  and init runs `git init --bare -b <branch> <dir>/.git` ("`git init-worktree`").
- **Did instead:**
  - clone and init unset `GIT_DIR`, `GIT_WORK_TREE`, `GIT_COMMON_DIR`, `GIT_INDEX_FILE`,
    `GIT_OBJECT_DIRECTORY` and the other repository-location variables first;
  - convert unsets them too, but refuses when a set `GIT_DIR` or `GIT_WORK_TREE` names a different repo
    than the one it was given: `GIT_DIR (<value>) is not the git directory of '<top>'; unset it, or pass the
    matching path`, and the same for `GIT_WORK_TREE`;
  - as a backstop, step 4 checks that `git worktree add` created exactly one new entry in `.git/worktrees`,
    and that it is the new worktree's git dir, before anything else uses it.
- **Why:** git exports `GIT_DIR` to a subcommand run as `git --git-dir=... <verb>`, and a shell may have it
  exported. The review showed that with an exported `GIT_DIR`, the recovery commands convert printed would
  `rm -rf` the real `.git` (a scratch repo was destroyed this way), and init made its root commit in
  another repository.
- **Affects:** `git-clone-worktree`, `git-init-worktree`, `git-convert-worktree`, `docs/usage.md`,
  `docs/architecture.md`, `docs/decisions.md` (9).

### 2026-11-12: Split index is carried over

- **Plan said:** "Copy `.git/index` and `.git/logs/HEAD` into the new worktree's git dir ... then remove
  the bare repo's index." (convert, step 5).
- **Did instead:** step 5 also copies the `sharedindex.*` files, and checks that the new worktree can read
  its index (`git ls-files --stage`) before it removes the original:
  `the new worktree can't read the copied index` stops the command, with recovery.
- **Why:** with `core.splitIndex` on, `.git/index` only holds changes on top of a `sharedindex.<hash>`
  file. In the review, after a conversion that copied only `index`, `git -C main status` failed with
  `fatal: <repo>/.git/worktrees/main/sharedindex.<sha>: index file open failed` (exit 128). Copying the
  `sharedindex.*` files as well restored the expected ` M a` and `A  staged`.
- **Affects:** `git-convert-worktree`, `docs/usage.md` (also the manual recipe), `docs/architecture.md`.

### 2026-11-12: Convert steps 2 to 7 ignore signals

- **Plan said:** "**On failure partway through:** stop and print exact recovery commands" (convert).
- **Did instead:** steps 2 to 7 ignore HUP, INT and TERM. Signals work again from step 8, where
  `git remote set-head` may wait on the network.
- **Why:** in the review, an INT sent during `git worktree repair` made convert exit 130, and the
  recovery commands it printed failed at once with
  `mv: cannot move 'a' to '../.convert-worktree.<pid>/': Not a directory`. On HUP, the recovery message
  goes to a terminal that is already gone. These steps take milliseconds, so ignoring signals during them
  costs nothing.
- **Affects:** `git-convert-worktree`, `docs/usage.md`, `docs/architecture.md`, `docs/decisions.md` (9).

### 2026-11-12: Recovery without prune

- **Plan said:** recovery prints "exact recovery commands (where the files are, `git config core.bare
  false`, how to move them back)" (convert).
- **Did instead:**
  - the recovery commands remove only the `.git/worktrees/<name>` entry this run created, and never
    `git worktree prune`;
  - a stop from step 7 on is reported as done, with one follow-up command:
    `stopped at step <n>, after every file was in place in <checkout>.`, then the repair or
    `git remote set-head` command;
  - a stop at step 2 says `Some of your files are in <stage>, the rest are still in <top>.`
- **Why:** the review showed that the printed `git worktree prune` also deleted the record of an outside
  linked worktree that was missing for the moment, and with it that worktree's staged change. From step 7
  on, every file is in place, so restore commands would undo good work.
- **Affects:** `git-convert-worktree`, `docs/usage.md`, `docs/architecture.md`, `docs/decisions.md` (9).

### 2026-11-12: Reflog test compares before and after

- **Plan said:** convert copies `.git/logs/HEAD` into the new worktree's git dir (step 5); the tests check
  that files and status survive ("Tests: `scripts/test-bare-worktree.sh`").
- **Did instead:** the test compares the HEAD reflog before and after the conversion.
- **Why:** the old assertion would have passed even if the reflog had not been copied, so it could not
  fail.
- **Affects:** `scripts/test-bare-worktree.sh`.

### 2026-11-12: Init root commit skips hooks and failures clean up

- **Plan said:** "Make an empty root commit so `wt switch -c` has something to branch from." ("`git
  init-worktree`", step 5).
- **Did instead:** the root commit uses `--no-verify`, so commit hooks do not run; `commit.gpgSign` still
  applies. If any step fails after the directory is created, init removes it and prints
  `removed the partial repository at <directory>`.
- **Why:** a global `pre-commit` or `commit-msg` hook could reject the empty commit, and the half-made
  repository left behind made a retry stop at "already exists". The hooks are for your commits, not for a
  placeholder.
- **Affects:** `git-init-worktree`, `docs/usage.md`, `docs/architecture.md`, `docs/gotchas.md`.

### 2026-11-12: Clone cleans up and names the folder like git clone

- **Plan said:** `git-clone-worktree` "takes over the body of the staged `wt-clone`", which left a partial
  clone in place on failure and took the folder name from the last path part.
- **Did instead:** a failure before the worktree exists removes the directory clone created and prints
  `removed the partial clone at <directory>`. The default folder name follows `git clone`: trailing `/`
  and `/.git` are dropped first, so `.../repo/.git`, `.../repo.git` and `host:path/repo.git` all give
  `repo`.
- **Why:** a retry after a failed clone stopped at "already exists". The old naming turned
  `<path>/repo/.git` into an empty name and refused it as an invalid destination.
- **Affects:** `git-clone-worktree`, `docs/usage.md`, `docs/architecture.md`.

### 2026-11-12: Dispatcher help without wt

- **Plan said:** "`git bare-worktree` runs the same check before dispatching." (Shared behaviour,
  Preflight).
- **Did instead:** `git bare-worktree <action> -h` and `git bwt <action> -h` skip the preflight and show
  the verb's usage. `switch -h` still needs wt, because it is wt's own help.
- **Why:** `git clone-worktree -h` worked without wt, but `git bwt clone -h` failed the preflight, so the
  same help behaved differently depending on how it was called.
- **Affects:** `git-bare-worktree`, `docs/usage.md`, `docs/architecture.md`, `docs/decisions.md` (4).

### 2026-11-12: Message accuracy and movability precheck

- **Plan said:** step 9 prints "a hint: `wt step relocate --dry-run` can move linked worktrees that sit
  outside the layout"; the refusals are the six in "Refuse, changing nothing, if" (convert).
- **Did instead:**
  - the hint counts only linked worktrees outside the repo folder:
    `Hint:     <n> linked worktree(s) outside the repo may not match the layout; preview moving them with:
    wt -C <checkout> step relocate --dry-run`;
  - the repair warning prints the exact `git -C <checkout> worktree repair <paths...>` command;
  - convert refuses when `.git/index.lock` exists, when the repo folder is not writable, and when a
    top-level folder is not writable: `'<entry>' is not writable, so it can't be moved; make it writable
    (chmod u+w) and retry`.
- **Why:** nested worktrees move with the files and are repaired, so counting them in the hint was wrong.
  The repair warning only named a placeholder. A rename needs write access to the folder it leaves, and a
  folder that changes parent must itself be writable; without the precheck, step 2 could stop halfway. A
  held `index.lock` means another git process may be writing the index that step 5 copies.
- **Affects:** `git-convert-worktree`, `docs/usage.md`, `docs/architecture.md`, `docs/decisions.md` (9).

### 2026-11-12: Convert refuses the home directory and root

- **Plan said:** the refusals in "Refuse, changing nothing, if" (convert) did not cover where the repo is.
- **Did instead:** convert refuses when the repo's top level is `$HOME` or `/`:
  `'<top>' is your home directory or /; moving everything in it is not supported`.
- **Why:** precautionary; this was not observed. A home directory kept as a git repo (for dotfiles) would
  have everything in it moved one folder down while the command runs, including `~/.local` (where tool
  shims live) and `~/.ssh`.
- **Affects:** `git-convert-worktree`, `docs/usage.md`, `docs/architecture.md`, `docs/decisions.md` (9).

### 2026-11-12: Formula test and atomic config.worktree write

- **Plan said:** in the Homebrew `test do`, "with `PATH` set explicitly to `bin` and the system dirs (no
  wt), `git clone-worktree` fails with the preflight message"; convert step 5 "rewrites" the bare repo's
  `config.worktree` (see [Convert with extensions.worktreeConfig](#2026-11-12-convert-with-extensionsworktreeconfig)).
- **Did instead:** the formula test calls `#{bin}/git-clone-worktree` directly. Convert writes the bare
  repo's new `config.worktree` beside the old one and renames it into place.
- **Why:** the preflight runs before any git call, so calling the script directly tests it without
  needing git on the build host. Writing in place could leave a half-written `config.worktree` if the step
  failed midway; a rename replaces it in one go.
- **Affects:** `packaging/git-toolbelt.rb`, `git-convert-worktree`.

### 2026-11-12: Re-review: four follow-up fixes

- **Plan said:** see the entries above; a second review of the fixes found four more problems.
- **Did instead:**
  - **A. Parent folders.** Clone and init create missing parent folders again
    (`git clone-worktree <repository> deep/a/b` works). On failure they remove only `<directory>`; parent
    folders they created stay. A regression test covers it.
  - **B. No user code while signals are ignored.** In convert's steps 2 to 7, `git worktree add` runs with
    `-c core.hooksPath=/dev/null`, and `read-tree` and `ls-files` with `-c core.fsmonitor=false`.
  - **C. Step-8 recovery.** A stop at step 8 now prints the remote setup that is still missing:
    ```
    git convert-worktree: stopped at step 8, after every file was in place in <checkout>.
      Finish the remote setup:
        git -C <checkout> config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
        git -C <checkout> remote set-head origin --auto
    ```
    The refspec line appears only when it should have been written and was not; the `set-head` line only
    when `origin` has a URL. It replaces `Then finish the remote setup if needed: ...`, which named only
    `set-head`.
  - **D. GIT_DIR from outside.** The script's comment and the docs now say what it does: `GIT_DIR` alone
    never selects the repo. `GIT_DIR=<repo>/.git git convert-worktree` run from outside `<repo>` refuses
    with `'.' is not inside a git repository`; pass `<repo>` or run inside it.
- **Why:**
  - A: the cleanup fix replaced `git clone --bare`'s own folder creation with a plain `mkdir`, so a nested
    destination failed with `mkdir: cannot create directory 'deep/a/b': No such file or directory`.
  - B: a program started while signals are ignored inherits that. In the review, a `reference-transaction`
    hook run by `git worktree add` ignored INT.
  - C: after a failure at step 8, the refspec could still be unset, and the old message did not say so.
  - D: the comment and the earlier docs said `git --git-dir=<repo>/.git convert-worktree` converts `<repo>`.
    That is only true when it runs inside `<repo>`; from anywhere else it refuses.
- **Affects:** `git-clone-worktree`, `git-init-worktree`, `git-convert-worktree`,
  `scripts/test-bare-worktree.sh`, `docs/usage.md`, `docs/architecture.md`, `docs/gotchas.md`.
