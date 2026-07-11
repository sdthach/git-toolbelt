Personal notes for publishing a new version of this fork (`sdthach/git-toolbelt`).

See [`docs/maintaining-the-fork.md`](docs/maintaining-the-fork.md) for the full picture (tap
bootstrap, install modes, upstream sync). Once `.github/workflows/release.yml` is in place, pushing a
`v*` tag does steps 3–5 automatically.

1. Update/check `CHANGELOG.md`.
1. Tag the version with Git (e.g. `git tag v1.2.3`).
1. Push the tag out (`git push origin v1.2.3`).
1. Create a release from the tag at https://github.com/sdthach/git-toolbelt/releases
1. Compute the SHA256 hash:
    `wget -O - https://github.com/sdthach/git-toolbelt/archive/refs/tags/vX.Y.Z.tar.gz | sha256sum`
1. In the `sdthach/homebrew-tap` repo, update the `url` + `sha256` in `git-toolbelt.rb` (and uncomment
   the stable stanza on the very first release).
