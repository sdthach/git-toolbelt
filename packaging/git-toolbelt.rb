# Homebrew formula for the git-toolbelt fork (github.com/sdthach/git-toolbelt).
#
# This file is the source of truth. The tap copy lives in
# github.com/sdthach/homebrew-tap/git-toolbelt.rb and is kept in sync by
# .github/workflows/release.yml (see docs/maintaining-the-fork.md).
#
# Homebrew and mise install the SAME artifact: the `git-toolbelt-X.Y.Z.tar.gz`
# release asset built by scripts/build-dist.sh, which already ships its commands
# flattened into bin/. That keeps the two distribution paths from drifting —
# there is one tarball, one sha256, and one layout to reason about.
#
# INSTALL
#   Stable (pinned release):  brew install sdthach/tap/git-toolbelt
#   HEAD (tip of main):       brew install --HEAD sdthach/tap/git-toolbelt
class GitToolbelt < Formula
  desc "Helper commands and g+verb shortcuts to make everyday life with Git easier"
  homepage "https://github.com/sdthach/git-toolbelt"
  license "BSD-3-Clause"

  # --- Stable stanza (rewritten in the tap by .github/workflows/release.yml) ---
  url "https://github.com/sdthach/git-toolbelt/releases/download/v1.12.0-fork.1/git-toolbelt-1.12.0-fork.1.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  head "https://github.com/sdthach/git-toolbelt.git", branch: "main"

  # git-relative-path needs GNU realpath; native on Linux, provided here for macOS.
  depends_on "coreutils"

  # Worktrunk is deliberately not a dependency: only the six bare-worktree
  # commands need it, and they say so (with install links) when it is missing.

  def install
    # A stable build unpacks the release tarball, which already has the
    # flattened bin/ and the bare-worktree docs and samples under share/. A
    # --HEAD build gets the repo layout instead, where the commands are still
    # split between the root, portmanteaus/ and bare-worktree/. 81 commands in
    # all: 61 + 14 + 6.
    if File.directory?("bin")
      bin.install Dir["bin/*"]
      pkgshare.install "share/git-toolbelt/bare-worktree"
    else
      bin.install Dir["git-*"]               # the 61 git-<verb> subcommands
      bin.install Dir["portmanteaus/*"]      # the 14 g+verb shortcuts (getch, gush, gome, ...)
      bin.install Dir["bare-worktree/git-*"] # the 6 bare-repo + worktree commands
      # Only git-* from bare-worktree/ is a command; the rest is docs and
      # samples, and docs/plans/ is repo-only history.
      (pkgshare/"bare-worktree").install "bare-worktree/README.md",
                                         "bare-worktree/config.toml.example",
                                         "bare-worktree/wt.toml.example"
      (pkgshare/"bare-worktree/docs").install Dir["bare-worktree/docs/*.md"]
    end
  end

  def caveats
    <<~EOS
      The bare-worktree commands (git clone-worktree, git init-worktree,
      git convert-worktree, git switch-worktree, git bare-worktree, git bwt)
      need Worktrunk (wt), which is not installed as a dependency:
        brew install worktrunk
        https://github.com/max-sixty/worktrunk#install

      Print a sample Worktrunk user config for the bare-repo layout with:
        git bare-worktree config-example

      The samples and the bare-worktree docs are installed in:
        #{opt_pkgshare}/bare-worktree
    EOS
  end

  test do
    # A git-* subcommand, a portmanteau shortcut and the bare-worktree commands
    # all landed on PATH, and the docs and samples landed in pkgshare.
    assert_path_exists bin/"git-main-branch"
    assert_path_exists bin/"getch"
    assert_path_exists bin/"git-bare-worktree"
    assert_path_exists bin/"git-bwt"
    assert_path_exists pkgshare/"bare-worktree/README.md"
    assert_path_exists pkgshare/"bare-worktree/config.toml.example"
    assert_path_exists pkgshare/"bare-worktree/wt.toml.example"
    assert_path_exists pkgshare/"bare-worktree/docs/getting-started.md"

    # git-main-branch actually resolves the main branch. Force the default branch
    # name and add a commit so the probe has a real branch to find, independent of
    # the ambient init.defaultBranch (brew's sandbox leaves it as "master").
    ENV.prepend_path "PATH", bin
    system "git", "-C", testpath, "-c", "init.defaultBranch=main", "init", "-q"
    system "git", "-C", testpath, "-c", "user.name=brew", "-c", "user.email=brew@example.com",
           "commit", "-q", "--allow-empty", "-m", "init"
    assert_equal "main", shell_output("git -C #{testpath} main-branch").strip

    # The sample printer needs neither Worktrunk nor a repo.
    assert_match "worktree-path", shell_output("git bare-worktree config-example")

    # Without wt on PATH, the bare-worktree commands stop at the preflight
    # before touching anything; the preflight runs before any git call, so
    # the script is called directly and needs no git on the host. PATH is set
    # explicitly so a wt from the environment can't leak in.
    output = shell_output("PATH=#{bin}:/usr/bin:/bin #{bin}/git-clone-worktree " \
                          "https://example.invalid/repo.git #{testpath}/clone 2>&1", 1)
    assert_match "Worktrunk (wt) is required", output
    refute_path_exists testpath/"clone"
  end
end
