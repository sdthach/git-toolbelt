# Decisions and trade-offs

Back to the [bare-worktree README](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/README.md).

One entry per decision. This page describes the current state. When a decision changes after the plan, its
entry is updated and links to the matching entry in the
[divergences record](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md).

## 1. No auto-cd

- **Decision:** clone, init, convert and switch never change your shell's directory. They print the path and
  the command to get there.
- **Why:** a git subcommand runs in a child process and cannot change its parent shell's directory. Only
  Worktrunk's shell function can. `git clone` behaves the same way.
- **Trade-off:** one extra `cd` (or `wt switch`, `z`) after each command.
- **Revisit if:** git gains a way for subcommands to change the caller's directory, or a shell wrapper
  proves worth shipping.

## 2. Native git verbs, not wt-* commands

- **Decision:** the commands are `git clone-worktree`, `git init-worktree`, `git convert-worktree` and
  `git switch-worktree`. The earlier `wt-clone` (a Worktrunk custom subcommand, `wt clone`) is gone.
- **Why:** they read as native git, sit beside the other `git-*` scripts in this toolbelt, and get git's
  command-name completion for free.
- **Trade-off:** longer names than `wt clone`, and they do not appear under `wt`.
- **Revisit if:** Worktrunk adds its own clone, init or convert commands.

## 3. Dispatcher git bare-worktree, alias git bwt

- **Decision:** one dispatcher, `git bare-worktree <action>`, with the short alias `git bwt`.
- **Why:** `git bare` was dropped because `git bare init` reads like `git init --bare`, which makes a bare
  repo with no checkout. `bare-worktree` matches the folder name. `git wt` was ruled out because Worktrunk
  installs itself as `git-wt` on Windows. `git bwt` is the short form for typing.
- **Trade-off:** three ways to call one command (verb, dispatcher, alias). This is accepted: `git bwt` is a
  two-line wrapper, so the forms cannot behave differently.
- **Revisit if:** one of the forms goes unused, or another tool claims `git-bwt`.

## 4. Worktrunk required at runtime, optional in packaging

- **Decision:** every command checks for `wt` first and stops with an install link if it is missing. The
  exceptions are `config-example` and `-h`, including `git bwt <action> -h`; only `switch -h`, which is
  wt's own help, needs wt ([divergence record](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-dispatcher-help-without-wt)). Packages do not depend on Worktrunk; the Homebrew formula has caveats instead of
  `depends_on`.
- **Why:** most of git-toolbelt does not need Worktrunk. A hard dependency would install it for everyone.
- **Trade-off:** you can install the package and only find out at first use that Worktrunk is missing. The
  preflight message makes that a one-step fix.
- **Revisit if:** most users of the package use the bare-worktree commands.

## 5. git switch-worktree is a pure passthrough

- **Decision:** `git switch-worktree` runs the preflight and then `exec wt switch "$@"`, with no argument
  parsing of its own.
- **Why:** wt's options keep changing. A passthrough never falls behind, and `-h` shows wt's real help.
- **Trade-off:** it adds nothing but the preflight and the git-style name, and it cannot change directory
  ([decision 1](#1-no-auto-cd)). wt's message about that suggests a `git-wt` command that does not exist on
  Linux or macOS ([divergence record](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-wt-messages-without-shell-integration)).
- **Revisit if:** there is behaviour worth adding that wt does not have.

## 6. Samples shipped twice: files and heredocs

- **Decision:** `config.toml.example` and `wt.toml.example` ship as files, and the same text sits in
  heredocs inside `git-bare-worktree` for `config-example`. A test keeps them byte-identical.
- **Why:** under mise shims a script cannot reliably find files next to itself. The files are still useful
  to read and to package.
- **Trade-off:** two copies to edit. The test catches drift.
- **Revisit if:** mise (or the install layout) gives scripts a reliable way to find their data files.

## 7. Folder names sanitized like wt; branch names kept

- **Decision:** the checkout folder for `feature/x` is `feature-x` (`/` and `\` become `-`). The branch
  stays `feature/x`.
- **Why:** it matches wt's `{{ branch | sanitize }}`, so the first checkout and every later `wt switch -c`
  follow the same rule.
- **Trade-off:** `feature/x` and `feature-x` map to the same folder, so wt refuses the second unless you pick
  another path.
- **Revisit if:** wt changes its sanitize filter.

## 8. The first checkout skips wt hooks

- **Decision:** the final `wt switch` uses `--no-hooks`. The scripts run `zoxide add` themselves.
- **Why:** project hooks would run before you have reviewed the repo's `.config/wt.toml`, and a
  just-converted repo should not start dev servers or installs on its own.
- **Trade-off:** your own `post-start` hooks do not run for the first checkout either. Run them by hand with
  `wt hook post-start` if you need them.
- **Revisit if:** wt can run only user hooks, not project hooks.

## 9. Convert refuses rather than guesses

- **Decision:** convert refuses, changing nothing, on a detached or unborn HEAD, a HEAD that is not a local
  branch, an operation in progress, a held `index.lock`, initialised submodules, sparse checkout, a linked
  worktree, a bare repo, a git directory other than `<repo>/.git`, a `GIT_DIR` or `GIT_WORK_TREE` that
  names another repo, your home directory or `/`, a folder it could not move, a worktree already
  registered at the target folder, or an existing stage folder. There is no automatic rollback. A failure
  while files are being moved (steps 2 to 6) prints recovery steps that remove only what this run created
  and never run `git worktree prune`; a failure after that prints the one follow-up command. Steps 2 to 7
  ignore HUP, INT and TERM. See the divergence records
  [four more convert refusals](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-four-more-convert-refusals),
  [repository variables](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-repository-variables-are-cleared-or-checked),
  [home directory and root](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-convert-refuses-the-home-directory-and-root),
  [movability precheck](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-message-accuracy-and-movability-precheck),
  [signals](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-convert-steps-2-to-7-ignore-signals) and
  [recovery without prune](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-recovery-without-prune).
- **Why:** each of these needs a choice only you can make, and a wrong guess could lose work. A rollback
  that runs after an unknown failure could make things worse; printed steps let you see what happens.
  Clone and init only create a new folder, so they do remove it when they fail.
- **Trade-off:** those repos need cleaning up by hand before they can be converted, and submodule repos
  cannot be converted at all.
- **Revisit if:** submodules or sparse checkouts turn out to be common in repos people want to convert.

## 10. A failing final wt switch only warns

- **Decision:** if the final `wt switch --no-cd --no-hooks` fails, the command prints a warning and exits 0.
- **Why:** by then the git work is complete and correct. The `wt switch` call only lets Worktrunk offer to
  save a layout.
- **Trade-off:** a broken wt setup shows up as a warning, not as a failure.
- **Revisit if:** the final `wt switch` starts doing work the layout depends on.

## 11. No custom tab completion

- **Decision:** no completion scripts are shipped.
- **Why:** git already completes the `git-*` command names, paths complete as file names, and branch names
  are covered by `wt switch <TAB>`, wt's picker, `z` and `zi`.
- **Trade-off:** `git switch-worktree <TAB>` does not complete branch names.
- **Revisit if:** people use `git switch-worktree` more than `wt switch` and miss branch completion.

## 12. zoxide and fzf optional; fzf key bindings off

- **Decision:** zoxide and fzf are never required. The docs set up `z` and `zi` but leave fzf's key bindings
  (`fzf --bash`) off.
- **Why:** `zi` only needs the fzf program. fzf's key bindings take Ctrl-R, which atuin also uses; whichever
  loads last wins. See
  [Works with atuin](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/gotchas.md#works-with-atuin).
- **Trade-off:** no fzf Ctrl-T or Alt-C unless you turn them on yourself. Since fzf 0.75 that is easy:
  `FZF_CTRL_R_COMMAND=` (empty) before `eval "$(fzf --bash)"` skips only Ctrl-R
  ([divergence record](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/plans/2026-11-12-bare-worktree-divergences.md#2026-11-12-fzf-ctrl-r-can-be-turned-off-alone)).
- **Revisit if:** you do not use atuin.

## 13. mise is the recommended install for wt, fzf and zoxide

- **Decision:** the docs recommend `mise use -g worktrunk fzf zoxide`, with `brew install worktrunk` and
  `cargo install worktrunk` as alternatives.
- **Why:** mise installs checksum-verified release binaries (through aqua), and one tool manager handles
  all three plus git-toolbelt. Worktrunk is not packaged for apt.
- **Trade-off:** people who do not use mise follow the alternatives.
- **Revisit if:** Worktrunk lands in mainstream distro packages, or mise's registry entries change backend.

## 14. The plan and its divergences are kept in the repo

- **Decision:** the approved plan is kept, redacted, in `docs/plans/`, next to a record of later decisions
  and every place the implementation differs from it. They are not shipped.
- **Why:** this page says what is true now; the plan says what was intended and why. Keeping both shows how
  a decision came about, the same idea as the repo's `docs/distribution-rework.md`.
- **Trade-off:** the plan is frozen, so it goes out of date by design. Readers must check the divergences
  record before trusting it.
- **Revisit if:** the record stops being updated, in which case it is better deleted than wrong.
