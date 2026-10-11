# Homebrew distribution

Rightform is distributed as a ready-made `.app` inside a GitHub Release ZIP.
Homebrew Cask verifies the ZIP checksum and installs `Rightform.app` in
`/Applications` without compiling Swift on the user's Mac.

This repository is the tap. Its `Casks/rightform.rb`:

- downloads an immutable versioned Release ZIP and checks its SHA-256;
- installs `Rightform.app` in `/Applications`;
- exposes `rightform` for Homebrew status, updates, and opening the app.

Users add the tap by URL, then trust the Cask once before installing it:

```zsh
brew tap prisonmike420/rightform https://github.com/prisonmike420/rightform
brew trust --cask prisonmike420/rightform/rightform
```

The Cask is generated only after the GitHub Release asset exists, because its
checksum must be the checksum served by GitHub. The `Build` workflow does this
on every commit to `main`: it builds the ZIP, publishes it in the GitHub
Release, fills `{{VERSION}}` and `{{SHA256}}` in `Casks/rightform.rb.template`
and pushes the result as `Casks/rightform.rb`, using the deploy key stored in
the `RELEASE_DEPLOY_KEY` secret. That key is the only actor allowed past the
`main` ruleset; the commit is marked `[skip ci]` so it doesn't release again.
