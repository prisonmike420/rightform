# Homebrew distribution

STOU is distributed as a ready-made `.app` inside a GitHub Release ZIP.
Homebrew Cask verifies the ZIP checksum and installs `STOU.app` in
`/Applications` without compiling Swift on the user's Mac.

This repository is the tap. Its `Casks/stou.rb`:

- downloads an immutable versioned Release ZIP and checks its SHA-256;
- installs `STOU.app` in `/Applications`;
- exposes `stou` for Homebrew status, updates, and opening the app.

Users add the tap by URL, then trust the Cask once before installing it:

```zsh
brew tap prisonmike420/stou https://github.com/prisonmike420/stou
brew trust --cask prisonmike420/stou/stou
```

The Cask is generated only after the GitHub Release asset exists, because its
checksum must be the checksum served by GitHub. The `Build` workflow does this
on every commit to `main`: it builds the ZIP, publishes it in the GitHub
Release, fills `{{VERSION}}` and `{{SHA256}}` in `Casks/stou.rb.template`
and pushes the result as `Casks/stou.rb`, using the deploy key stored in
the `RELEASE_DEPLOY_KEY` secret. That key is the only actor allowed past the
`main` ruleset; the commit is marked `[skip ci]` so it doesn't release again.

The Cask was called `rightform` before the app became STOU. The same commit
copies `packaging/homebrew/cask_renames.json` to the tap root and removes
`Casks/rightform.rb`, so Homebrew moves existing `rightform` installs to `stou`
on their next update. Both land only with a `stou.rb` whose ZIP exists.
