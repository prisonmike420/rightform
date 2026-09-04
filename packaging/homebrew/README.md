# Homebrew distribution

Rightform is a macOS application, but the current upstream build is intentionally
compiled on the user's Mac from the tagged source. This avoids publishing an
ad-hoc-signed app bundle that Gatekeeper would treat as an unidentified download.

The published `homebrew-rightform` tap contains the formula. It:

- downloads an immutable `v0.16.0` source tag and checks its SHA-256;
- declares the five core engines as dependencies;
- compiles `Rightform.app` with Apple Command Line Tools;
- keeps the application inside Homebrew's Cellar and exposes `rightform`, a small
  launcher that opens the bundle.

The formula is generated only after the GitHub release tag exists, because its
source archive checksum must be the checksum served by GitHub.
