# IMGLESS

Native macOS utility for local batch optimization of JPEG, PNG and WebP files.
Drop files into the window; IMGLESS identifies the format, checks its available
capabilities, processes and verifies the result, then saves it safely.

Version: **0.15.1** · Minimum macOS: **13.0**

## Install from source

Requirements: macOS 13 or later, Apple Command Line Tools and Homebrew.

1. Download this repository's source archive or clone it.
2. Double-click `Install.command`.

The installer uses Homebrew for the core engines (`jpeg-archive`, `jpeg-turbo`,
`pngquant`, `oxipng`, `webp`), compiles the app locally and installs it to
`~/Applications/IMGLESS.app` only after a successful build.

`Uninstall.command` removes only the application bundle. Extensions, settings
and statistics stay on the Mac unless removed separately.

## Homebrew

After the tagged GitHub release and its companion `homebrew-imgless` tap are
published, installation is:

```zsh
brew install prisonmike420/imgless/imgless
imgless
```

The Homebrew formula builds the app locally and opens it through `imgless`. This
is the correct distribution form for the current ad-hoc-signed build; a normal
`brew install --cask` release requires Developer ID signing and notarization.

## Core formats

- JPEG — `jpeg-recompress` and optional progressive `jpegtran`
- PNG — `pngquant` and `oxipng`
- WebP — `cwebp` and `dwebp`

Extensions add JPEGli, Apple Photos formats, RAW/TIFF, animation, legacy
formats, metadata cleanup, experimental AI-provenance cleanup and PDF tools.
They are installed on demand from the Settings drawer.

## Repository layout

```text
Sources/IMGLESS.swift      application implementation
Resources/                 Info.plist and app icon
scripts/build-app.sh       reproducible local app-bundle build
Install.command            source-archive installer
Uninstall.command          app-bundle removal
packaging/homebrew/        tap release notes and formula template location
```

## Licence

[MIT](LICENSE)
