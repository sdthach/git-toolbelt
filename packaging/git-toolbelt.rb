# Homebrew formula for the git-toolbelt fork (github.com/sdthach/git-toolbelt).
#
# This file is the source of truth. The tap copy lives in
# github.com/sdthach/homebrew-tap/git-toolbelt.rb and is kept in sync by
# .github/workflows/release.yml (see docs/maintaining-the-fork.md).
#
# INSTALL OPTIONS
#   1. HEAD (available now) — tracks the tip of main:
#          brew install --HEAD sdthach/tap/git-toolbelt
#   2. Stable (available after the first fork release is cut) — pinned tag:
#          brew install sdthach/tap/git-toolbelt
#      The `url` + `sha256` below are commented out until that first release;
#      release.yml populates them when a `v*` tag is pushed. Until then this is
#      a HEAD-only formula and `brew install` without `--HEAD` will report that
#      no stable version is available.
class GitToolbelt < Formula
  desc "Helper commands and g+verb shortcuts to make everyday life with Git easier"
  homepage "https://github.com/sdthach/git-toolbelt"
  license "BSD-3-Clause"
  head "https://github.com/sdthach/git-toolbelt.git", branch: "main"

  # --- Stable stanza (populated in the tap by .github/workflows/release.yml) ---
  # url "https://github.com/sdthach/git-toolbelt/archive/refs/tags/vX.Y.Z.tar.gz"
  # sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  # version "X.Y.Z"  # pinned: brew mis-parses "-fork.N" tags down to a bare number

  # git-relative-path needs GNU realpath; native on Linux, provided here for macOS.
  depends_on "coreutils"

  def install
    bin.install Dir["git-*"]          # the ~62 git-<verb> subcommands
    bin.install Dir["portmanteaus/*"] # the g+verb shortcuts (getch, gush, gome, ...)
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
