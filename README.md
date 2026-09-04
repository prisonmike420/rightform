# RIGHTFORM

**Files, ready for what’s next.**

Rightform is a native macOS app for preparing files locally and safely. Drop a batch of images, let Rightform inspect what it can handle, process it with the available capabilities, verify the result, and save it without replacing an original with a worse file.

The current release is an image-first utility for JPEG, PNG and WebP. PDF, photography, animation, metadata and other formats are optional extensions.

> **Project status:** `0.16.0` is the renamed continuation of IMGLESS. The intent-first Rightform experience described in [Product direction](docs/product-direction.md) is a design target, not a claim about the current UI.

## What it does today

- Processes JPEG, PNG and WebP batches locally.
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
| Core | JPEG, PNG, WebP | Built in after installation |
| Apple Photos | HEIC, HEIF, AVIF | Extension |
| Photography | TIFF, BigTIFF-like files, DNG and common camera RAW | Extension |
| Animation | GIF, APNG, Animated WebP | Extension |
| Legacy formats | BMP, TGA, PCX, PICT, PNM, XBM, XPM, SGI, Sun Raster | Extension |
| PDF Tools | PDF compression and duplicate-page analysis | Extension |

Extensions are optional and installed from **Settings → Extensions**. They bring only the engines required for that capability; the core workflow remains JPEG, PNG and WebP.

## Install from source

### Requirements

- macOS 13 or later
- Apple Command Line Tools or Xcode with a compatible macOS SDK
- [Homebrew](https://brew.sh/)

Clone the repository or download a source archive, then double-click `Install.command`.

The installer installs the core engines through Homebrew:

```text
jpeg-archive  jpeg-turbo  pngquant  oxipng  webp
```

It builds `Rightform.app` locally, ad-hoc signs it, and replaces `~/Applications/Rightform.app` only after a successful build. A failed compile does not replace an existing app.

To remove the app bundle, run `Uninstall.command`. It deliberately leaves extensions, preferences and statistics in place.

## Homebrew

The formula template is kept in [`packaging/homebrew/Formula/rightform.rb.template`](packaging/homebrew/Formula/rightform.rb.template). It is not yet installable: the source repository and companion tap must be public and the release archive SHA-256 must be recorded first.

Once a public tap exists, the intended command is:

```zsh
brew install prisonmike420/rightform/rightform
rightform
```

The formula builds the app from a tagged source archive. A downloadable Cask is not appropriate until releases are signed with a Developer ID certificate and notarized by Apple.

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
packaging/homebrew/          formula template and release notes
docs/product-direction.md    v1 product and interface direction
```

## Product direction

The project is moving from choosing encoder settings toward expressing intent: the user says what comes next for a file, while Rightform chooses and verifies the appropriate processing. The proposed v1 vocabulary is **Routine** (why a file is being prepared), **Where to?** (delivery) and **Afterwards** (retention).

See [Product direction](docs/product-direction.md) for the boundary between the current implementation and this planned model, visual principles, and naming considerations.

## License

[MIT](LICENSE)
