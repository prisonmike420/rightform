# RIGHTFORM

**Files, ready for what’s next.**

Rightform is a native macOS app for preparing files locally and safely. The app starts as a small shell: choose the file plugins you need, then Rightform installs only the engines needed for those capabilities.

The current release offers modular local file processing. Images, PDF, photography, animation, metadata and other capabilities are installed independently.

> **Project status:** `0.17.4` is the renamed continuation of IMGLESS. The intent-first Rightform experience described in [Product direction](docs/product-direction.md) is a design target, not a claim about the current UI.

## What it does today

- Processes installed file plugins locally.
- Detects files from content signatures, not only filename extensions.
- Handles files dropped onto the window, selected in the file picker and found recursively in folders.
- Resizes without upscaling; can convert output formats and prepare colour for sharing.
- Uses safe naming and collision handling; retains the original by default.
- Refuses a larger result when no conversion, resize or colour processing was requested.
- Inspects the produced file before finalizing it.
- Keeps RAW originals intact, even when replacement is otherwise enabled.

## Supported formats

| Capability | Formats | Availability |
| --- | --- | --- |
| Images | JPEG, PNG, WebP | Plugin |
| Apple Photos | HEIC, HEIF, AVIF | Plugin |
| Photography | TIFF, BigTIFF-like files, DNG and common camera RAW | Plugin |
| Animation | GIF, APNG, Animated WebP | Plugin |
| Legacy formats | BMP, TGA, PCX, PICT, PNM, XBM, XPM, SGI, Sun Raster | Plugin |
| PDF Tools | PDF compression and duplicate-page analysis | Plugin |

Plugins are optional and installed from **Settings → Plugins**. They bring only the engines required for that capability; the app itself does not install image or PDF engines until the user selects a plugin.

## Install from source

### Requirements

- macOS 13 or later
- Apple Command Line Tools or Xcode with a compatible macOS SDK
- [Homebrew](https://brew.sh/) — required only when installing a processing plugin

Clone the repository or download a source archive, then double-click `Install.command`.

It builds `Rightform.app` locally, ad-hoc signs it, and replaces `~/Applications/Rightform.app` only after a successful build. A failed compile does not replace an existing app.

On first launch, choose plugins in **Settings → Plugins**. Rightform asks Homebrew to install the selected plugin's engines, then verifies them before making the capability available.

To remove the app bundle, run `Uninstall.command`. It deliberately leaves extensions, preferences and statistics in place.

## Homebrew

The official Cask lives in the [homebrew-rightform](https://github.com/prisonmike420/homebrew-rightform) tap. It downloads the ready-made `Rightform.app` from the immutable GitHub Release ZIP, checks its SHA-256, and installs it in `/Applications` without compiling Swift locally.

Install Rightform with:

```zsh
brew install --cask prisonmike420/rightform/rightform
```

If you installed an older source-building Formula, migrate once:

```zsh
brew uninstall rightform
brew install --cask prisonmike420/rightform/rightform
```

The graphical app is the only interface for files and plugins. The terminal command is deliberately limited to Homebrew information and updates:

```zsh
rightform info
rightform update
rightform app
```

After a published GitHub Release, Rightform checks for a newer version from Settings and shows an **Update & open** button below Statistics. The button opens Terminal with the Homebrew update command, reports success, then opens the fresh app. It never updates Homebrew or the app silently.

The current Cask is intentionally unsigned while the product is early. macOS may require the user to choose **Open Anyway** in Privacy & Security after installation. The release ZIP is still checksum-verified by Homebrew. Developer ID signing and notarization will remove that Gatekeeper step later.

## Safety model

Rightform follows a local inspect → process → verify → finalize flow.

- Originals are kept by default.
- If replacement is enabled, an original is changed only after output succeeds.
- Static optimization avoids saving a larger result by default.
- RAW files always create a derivative; they are never overwritten.
- PDF output is validated with the installed tools when PDF Tools is used.

These are implementation guarantees of the current app, not cloud processing or an upload service: Rightform works on the Mac.

## Project structure

```text
Sources/Rightform.swift      native SwiftUI application
Resources/                   app metadata and icon source
scripts/build-app.sh         reproducible app-bundle build
Install.command              source installer
Uninstall.command            app-bundle removal
packaging/homebrew/          Homebrew Cask template and release notes
docs/product-direction.md    v1 product and interface direction
```

## Product direction

The project is moving from choosing encoder settings toward expressing intent: the user says what comes next for a file, while Rightform chooses and verifies the appropriate processing. The proposed v1 vocabulary is **Routine** (why a file is being prepared), **Where to?** (delivery) and **Afterwards** (retention).

See [Product direction](docs/product-direction.md) for the boundary between the current implementation and this planned model, visual principles, and naming considerations.

## License

[MIT](LICENSE)
