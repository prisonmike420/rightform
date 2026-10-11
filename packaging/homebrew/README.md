# Homebrew distribution

Rightform is distributed as a ready-made `.app` inside a GitHub Release ZIP.
Homebrew Cask verifies the ZIP checksum and installs `Rightform.app` in
`/Applications` without compiling Swift on the user's Mac.

The published `homebrew-rightform` tap contains the Cask. It:

- downloads an immutable versioned Release ZIP and checks its SHA-256;
- installs `Rightform.app` in `/Applications`;
- exposes `rightform` for Homebrew status, updates, and opening the app.

On current Homebrew versions, users trust this Cask once before installing it:

```zsh
brew trust --cask prisonmike420/rightform/rightform
```

The Cask is generated only after the GitHub Release asset exists, because its
checksum must be the checksum served by GitHub.

`scripts/release.sh` does all of this: it builds the ZIP, publishes it in the
GitHub Release, writes its checksum into `Casks/rightform.rb.template` and
commits the same Cask to the local `homebrew-rightform` tap.
