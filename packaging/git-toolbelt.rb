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

  def install
    # A stable build unpacks the release tarball, which already has the
    # flattened bin/. A --HEAD build gets the repo layout instead, where the
    # commands are still split between the root and portmanteaus/.
    if File.directory?("bin")
      bin.install Dir["bin/*"]
    else
      bin.install Dir["git-*"]          # the 62 git-<verb> subcommands
      bin.install Dir["portmanteaus/*"] # the g+verb shortcuts (getch, gush, gome, ...)
    end
  end

  test do
    # A git-* subcommand and a portmanteau shortcut both landed on PATH.
    assert_path_exists bin/"git-main-branch"
    assert_path_exists bin/"getch"

    # git-main-branch actually resolves the main branch. Force the default branch
    # name and add a commit so the probe has a real branch to find, independent of
    # the ambient init.defaultBranch (brew's sandbox leaves it as "master").
    ENV.prepend_path "PATH", bin
    system "git", "-C", testpath, "-c", "init.defaultBranch=main", "init", "-q"
    system "git", "-C", testpath, "-c", "user.name=brew", "-c", "user.email=brew@example.com",
           "commit", "-q", "--allow-empty", "-m", "init"
    assert_equal "main", shell_output("git -C #{testpath} main-branch").strip
  end
end
