# Homebrew distribution

Rightform is a macOS application, but the current upstream build is intentionally
compiled on the user's Mac from the tagged source. This avoids publishing an
ad-hoc-signed app bundle that Gatekeeper would treat as an unidentified download.

The published `homebrew-rightform` tap contains the formula. It:

- downloads an immutable `v0.17.2` source tag and checks its SHA-256;
- keeps file-processing engines optional until their module is selected in the app;
- compiles `Rightform.app` with Apple Command Line Tools;
- keeps the application inside Homebrew's Cellar and exposes `rightform` for
  Homebrew status, updates, and opening the app.

The formula is generated only after the GitHub release tag exists, because its
source archive checksum must be the checksum served by GitHub.
