# Homebrew distribution

IMGLESS is a macOS application, but the current upstream build is intentionally
compiled on the user's Mac from the tagged source. This avoids publishing an
ad-hoc-signed app bundle that Gatekeeper would treat as an unidentified download.

The release process creates a separate `homebrew-imgless` tap. Its formula:

- downloads an immutable `v0.15.1` source tag and checks its SHA-256;
- declares the five core engines as dependencies;
- compiles `IMGLESS.app` with Apple Command Line Tools;
- keeps the application inside Homebrew's Cellar and exposes `imgless`, a small
  launcher that opens the bundle.

The formula is generated only after the GitHub release tag exists, because its
source archive checksum must be the checksum served by GitHub.
