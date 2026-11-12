# Getting started

Back to the [bare-worktree README](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/README.md).

This page takes you from nothing to a first worktree in about five minutes.

## Install

Install git-toolbelt, Worktrunk, fzf and zoxide with [mise](https://mise.jdx.dev):

```console
$ mise use -g github:sdthach/git-toolbelt worktrunk fzf zoxide
```

mise installs checksum-verified release binaries for all four. Only Worktrunk is required; fzf and zoxide
are optional helpers for moving between worktrees.

Other ways to install Worktrunk:

```console
$ brew install worktrunk
$ cargo install worktrunk
```

Worktrunk's README lists more options: https://github.com/max-sixty/worktrunk#install. Worktrunk is not
packaged for apt. fzf and zoxide are in most package managers.

git-toolbelt itself can also come from Homebrew. See the
[install guide](https://github.com/sdthach/git-toolbelt/blob/main/docs/install.md).

You also need git. `git init-worktree` needs git 2.42 or later, because it uses `git worktree add --orphan`.

Check that everything is on `PATH`:

```console
$ wt --version
$ git bare-worktree -h
```

## Setting up Worktrunk

The bare-worktree commands print this section's address when `wt` is missing.

1. Install Worktrunk's shell integration, then restart the shell:

   ```console
   $ wt config shell install
   ```

   This adds one line to your shell's startup file. Without it, `wt switch` cannot change your directory.

2. Check that `wt` is now a shell function, not just the program:

   ```console
   $ type wt
   ```

   bash prints `wt is a function`. If it prints a path instead, the shell integration is not loaded.

3. Find your user config:

   ```console
   $ wt config show
   ```

   If it says the file does not exist, create it:

   ```console
   $ wt config create
   ```

4. Print the sample user config:

   ```console
   $ git bare-worktree config-example
   ```

   Copy its `worktree-path` line into your user config by hand:

   ```toml
   worktree-path = "{{ repo_path }}/../{{ branch | sanitize }}"
   ```

   Do not redirect the output with `>`; that would overwrite your existing config. The rest of the sample is
   commented out. Take what you want from it.

With that line in place, `wt switch -c feat/x` inside `repo/main` creates `repo/feat-x`, next to `main`.
[Architecture](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/architecture.md#how-worktrunk-config-combines)
explains how the user config, per-repo overrides and the project config fit together.

### Shell startup order

The tools must be set up in this order in your shell's startup file (`~/.bashrc` for bash):

1. `mise activate`, so the other tools are on `PATH`;
2. Worktrunk's shell integration (the line `wt config shell install` added);
3. `eval "$(zoxide init bash)"`, as the very last line.

If you use atuin, read
[Works with atuin](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/gotchas.md#works-with-atuin)
before you turn on fzf's key bindings.

## Optional: zoxide and fzf

zoxide gives you `z` (jump to a folder you have visited) and `zi` (pick one from a list). `zi` uses the fzf
program for its list. You do not need fzf's key bindings for this.

1. Add zoxide to the end of `~/.bashrc`, after everything else:

   ```bash
   eval "$(zoxide init bash)"
   ```

   For zsh, use `eval "$(zoxide init zsh)"` at the end of `~/.zshrc`.

2. Restart the shell. `type z zi` should show two functions.

3. Optional: keep zoxide's list in step with your worktrees. The sample user config has this block,
   commented out. Uncomment it in your user config:

   ```toml
   # Keep zoxide's list in sync with your worktrees (needs zoxide on PATH).
   post-start  = "zoxide add {{ worktree_path }}"
   post-remove = "zoxide remove {{ worktree_path }}"
   ```

   Without it, zoxide only learns a worktree after you `cd` into it. With it, every worktree is known as
   soon as wt creates it, even if you never visit it. Check that wt reads the hooks with `wt hook show`.

The clone, init and convert commands add their first checkout to zoxide themselves when zoxide is on
`PATH`. Daily use is in
[Usage](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/usage.md#moving-around).

## First repo

Pick one.

Clone a remote:

```console
$ cd ~/repos
$ git clone-worktree https://github.com/sdthach/git-toolbelt
```

Start a new repo:

```console
$ cd ~/repos
$ git init-worktree my-project
```

Convert a clone you already have:

```console
$ cd ~/repos/my-clone
$ git convert-worktree --dry-run     # shows what it would do
$ git convert-worktree
```

Each command ends with lines like these:

```

Checkout: /work/repos/git-toolbelt/main
Next:     cd /work/repos/git-toolbelt/main   # or: wt -C /work/repos/git-toolbelt switch main   |   z git-toolbelt main
```

The `|   z ...` part appears only when zoxide is on `PATH`. The format is described in
[Usage](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/usage.md#output).

`cd` into the `Checkout:` path. From there, `wt switch -c <branch>` creates the next worktree beside it.

## Next steps

- [Usage](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/usage.md): the daily workflow,
  every command's options and messages, and manual recipes.
- [Gotchas](https://github.com/sdthach/git-toolbelt/blob/main/bare-worktree/docs/gotchas.md): read this before
  you convert a repo you use every day.
