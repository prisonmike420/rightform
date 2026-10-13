# Stou

![Stou — Drop it. Consider it done. Files fly into a cobalt tile with a deep square well and come out checked.](brand/github/stou-readme-cover.png)

Stou is a native macOS app you drop files into. You say what they are for — a chat, an email, a website, print, the archive — and hand over the rest: Stou works out what each file needs, prepares it on your Mac, checks the result and delivers it where it has to go.

You don’t think about codecs, resolutions, colour profiles or leftover copies. **You decide the goal. Stou decides the method.**

> **Project status:** Stou is the continuation of Rightform (and IMGLESS before it); the version is in [`VERSION`](VERSION). Routines are in the app; per-file planning, delivery destinations and retention are the product target and are being built in phases. Sections marked **Today** describe shipped behaviour; sections marked **Planned** do not.

## The idea

Someone with 40 photos for a website should not have to decide on resolution, WebP vs JPEG, ICC profiles, sRGB, EXIF, compression levels, output folders and leftover copies. Their actual task is “get these photos ready for the site”. Stou is the place they drop them and stop worrying.

Every Stou job answers four questions:

| Question | Meaning | Example |
| --- | --- | --- |
| **What?** | The files you dropped | 18 photos |
| **What’s next?** | Why they are being prepared — the *Routine* | Web |
| **Where to?** | Where the result goes — *Delivery* | Website Assets |
| **Afterwards?** | What stays once it is delivered — *Retention* | Keep originals |

Stou turns those answers into a per-file processing plan. One Routine does not mean one operation: in a single Web batch a PNG may become WebP, a JPEG may be resized, a screenshot with transparency may stay PNG, and a file that already fits is left alone as **Already ready**.

### The app

The window opens at 960 × 640 (at least 720 × 520) and is laid out in fixed zones: a narrow **rail** on the left, the **work zone** in the middle and a **floating panel** on the right. There is no header. Pages only change what's in the work zone and the panel; the rail and the corner button stay where they are.

The rail works like a vertical tab bar: **Plugins** as a round button at the top; the places — **Home** and your installed plugins as round tiles the size of the tab, pinned ones first (right-click a plugin to pin it) — as tabs in one capsule; and at the bottom **Update Stou**, a filled blue round button, while there is an update, and **Settings**. Names show on hover. The window's top-right corner holds the panel's button, in that corner whether the panel shows or not. Dragging the top of the work zone or the panel's title row moves the window. The whole work zone takes dropped files and turns lightly tinted while they're dragged over it.

The places are the first level. **Plugins** and **Settings** are a second level across the whole window, with no panel: **Back** (or View › Back, ⌘[) at their top left returns to the place they were opened from, and the place tabs are disabled meanwhile, while Plugins and Settings switch between each other directly. Any place, the store and Settings are at most three clicks apart.

**Plugins** — at the top of the rail, or Stou › Plugins… (⇧⌘P) — is the plugin store: every plugin as a card by category, with its icon, what it does and a link to its included tools and licences, and one button in the card's corner: **+** installs it, a spinner shows the install (with **Cancel** beside the link), **↻** tries again after a failure, and a green check marks it installed and opens it. An install carries on after leaving the store. A plugin installed while the store is still in front opens in its workspace once it's ready.

Home and each plugin with settings have a panel on the right, shown or hidden with the button in the window's top-right corner or View › Show Inspector (⌥⌘I); it pushes the work zone aside rather than covering it, and its button is disabled where there's no panel: in the store, in Settings and in a plugin with nothing to set (Apple Photos, Metadata Cleaner); the choice holds for all of them, and installing a plugin shows it again. It's one surface with no cards inside, titled with what it holds. On Home it holds My Settings (the size, format and quality behind **Use my settings**). On a plugin it's titled with the plugin's name, then shows what the plugin does and its settings. While a batch runs, changes apply to the next one.

Settings holds only what applies to the whole app: the theme, favourite folders, file names, whether to quit when done, and About: version, update check (while an update waits, only the rail's blue button offers it; Settings shows its progress and any failure), usage so far and links to support, release notes and the source code. It also opens from Stou › Settings… (⌘,).

- **Home** takes any supported file. It shows what was dropped and what can be done with it — the routines below, or an installed plugin that takes all of the files — and nothing changes until you choose.
- **A plugin's workspace** does that plugin's one job, for example Metadata Cleaner removes hidden details and PDF Tools makes PDFs lighter. It takes only that plugin's formats and leaves everything else about the files as it was.

### Routines

A routine names what the files are for, in everyday words.

| Routine | What happens |
| --- | --- |
| **Send in a chat** | Lighter, text stays sharp, location removed* |
| **Attach to an email** | Small enough to attach; PDF text stays selectable |
| **Put on a website** | Up to 2400 px, WebP, sRGB, hidden details removed* |
| **Post on social media** | Feed size, sRGB, private details removed* |
| **Print** | Full size and quality, colour profile kept |
| **Keep for later** | Lossless only; all details kept |
| **Use my settings** | Whatever is set under My Settings in Home's panel |

\* Only with the Metadata Cleaner plugin installed; otherwise the routine says so and keeps them.

A routine sets quality, size, format, colour and hidden details, and plans each file: on a website photos become WebP while screenshots and graphics stay PNG; for chats and email, HEIC and AVIF become JPEG; for print and keeping, formats never change. The finer per-format controls stay in each plugin's panel.

**Use my settings** is for people who would rather decide the method themselves. Under *My Settings* in Home's panel you choose:

- **Size:** Original, Fit within, Max width, Max height, Max long edge or Max short edge (these only ever make an image smaller), Width or Height (that side exactly, enlarging a smaller image), or Percentage (1–100%).
- **Format:** Original, JPEG, PNG or WebP, and HEIC, AVIF or TIFF with their plugins. It applies to every still image.
- **Quality**, whether some quality loss is allowed, converting colours for sharing (sRGB), removing the colour profile, and removing hidden details (with Metadata Cleaner).

Animations, camera RAW and PDFs follow their plugins' own settings. The Animation plugin's panel sets the frame rate (Automatic, Original or 4–120 fps, 23.976, 29.97 and 59.94 included), loop, size, compression and output: an animated image, or a video without sound — MP4 (H.264), HEVC, WebM (VP9) or AV1. In a video, transparent areas become white, except in WebM. The other routines never use My Settings.

### Where to? and afterwards

After choosing what to do, every job asks where the results go — nothing is carried over from the last one:

- **Next to the originals**, named with the suffix from Settings (`photo_prepared.jpg`).
- **A favourite folder** (set in Settings) or **Choose Folder…** for this job.
- **Copy** — the files go on the clipboard, ready to paste into a chat, an email or Finder.
- **Share…** — the macOS Share sheet: Mail, Messages, AirDrop and more.

**Afterwards:** originals stay unless you turn on *Move originals to the Trash* — and then only after each new file is saved and checked. RAW originals always stay; copied or shared files never trash their originals.

**Going back:** every step before files are written has a way back, with Esc as well as a button. **Back** on Where to? returns to the choice of what to do (in a plugin's workspace, to the empty window). **Cancel** on the progress screen, while plugins install, labels are checked or PDFs are read, goes back a step: to Where to?, or to the choice at Home. **Back** on the PDF estimate returns to Where to?, and on the AI-label report at Home to the choice of what to do. After a batch, **Back** under Show Details returns to the summary. While files are being prepared, **Stop** ends the batch.

Prepared files wait in a Results folder until delivered. Saved files move out and the folder goes; copied or shared ones stay while they may still be pasted or sent, and anything older than a day is cleared at launch.

## What Stou is not

Stou is not a file manager, a photo library, a photo or RAW editor, a cloud service, a chatbot, or a panel of encoder settings. It is the slot between the file you have and the next thing you do with it.

## Principles

- **Local-first.** Processing happens on the Mac. No account, no uploads. Any future cloud destination will need separate, explicit consent.
- **Minimal intervention.** Stou doesn’t convert a file just because it can. A file that already fits is passed through unchanged.
- **Verify before delivering.** Output is decoded and checked against the plan. A file that fails verification is never presented as a success.
- **No silent loss.** Stou asks first before anything significant changes: lost transparency, removed metadata, lower resolution, lost selectable text in a PDF, rasterization, removed pages or a removed original.
- **Deterministic first.** Decisions come from inspectable rules and the capabilities actually installed, not from an opaque model.
- **Honest results.** Typical results are *Already optimal*, *Passed through unchanged*, *Could not reach the requested size* and *17 of 18 ready, 1 needs attention*. A partial failure never hides the files that succeeded.

## What it does today

- Processes files with installed plugins, locally.
- Detects files from content signatures, not only filename extensions.
- Handles files and folders dropped onto the window or the Dock icon, opened with Stou from Finder, or selected in the file picker; folders are searched recursively.
- Can quit once a batch is saved (*Quit when done* in Settings); it stays open when a file needs attention, and after Copy or Share.
- Resizes without upscaling, unless *Use my settings* asks for an exact width or height; can convert output formats, prepare colour for sharing and remove colour profiles.
- Uses safe naming and collision handling; keeps the original by default.
- Refuses a larger result when no conversion, resize or colour processing was requested.
- Inspects the produced file before finalizing it.
- Keeps RAW originals intact, even when replacement is otherwise enabled.
- Schedules light and heavy jobs adaptively based on available CPU and memory, with cancellation.

## Supported formats

| Capability | Formats | Availability |
| --- | --- | --- |
| Images | JPEG, PNG, WebP | Plugin |
| High-quality JPEG | JPEG via Google jpegli | Plugin |
| Apple Photos | HEIC, HEIF, AVIF | Plugin |
| Photography | TIFF, BigTIFF-like files, DNG and common camera RAW | Plugin |
| Animation | GIF, APNG, Animated WebP; output also as MP4 (H.264), HEVC, WebM (VP9) or AV1 video | Plugin |
| Legacy formats | BMP, TGA, PCX, PICT, PNM, XBM, XPM, SGI, Sun Raster | Plugin |
| Metadata Cleaner | Metadata removal for supported images | Plugin |
| AI Provenance | Experimental; off unless explicitly enabled | Plugin |
| PDF Tools | PDF compression and duplicate-page analysis | Plugin |

Plugins are optional and are installed from Plugins in the rail. Each one brings only the engines it needs. The app installs no image or PDF engines until you select a plugin.

Once a week Stou asks Homebrew whether the engines of your installed plugins have newer versions. To the person using Stou there is only one update: newer plugin engines and a new Stou release are offered and installed together, as **Update Stou**, with no difference shown between them. Underneath, Stou first runs `brew upgrade` for just those packages and then, if there is one, installs the new release. If the engines fail, the release isn't installed and Settings says what went wrong. **Check for Updates** asks GitHub and Homebrew again at any time. Plugins built from source (High-Quality JPEG, AI Provenance) aren't covered. Both need Homebrew.

The engines are open-source projects by other authors. Stou installs them through Homebrew or builds a pinned upstream revision locally; it does not bundle, modify or re-sign them. They are listed below, plugin by plugin, with what their licences mean for Stou under [Licences of the engines](#licences-of-the-engines). Each plugin in the app links to its section here: in the store before it's installed, then from its panel.

If a Routine needs a capability that is not installed, Stou will say what is missing and offer to install it. It will not deliver a partial result as if it met the Routine.

## Plugins and their tools

What each plugin installs, under which licence, and where the project lives. This list is generated from [`Resources/plugins.json`](Resources/plugins.json) — the same catalogue the app installs from — so it changes only together with it.

<!-- plugin-tools:start -->
<!-- Generated by scripts/update-plugin-tools.sh from Resources/plugins.json. Edit those, not this. -->

### Images

| Tool | Licence | Installed |
| --- | --- | --- |
| [JPEG Archive](https://github.com/danielgtaylor/jpeg-archive) | MIT | Homebrew `jpeg-archive` |
| [libjpeg-turbo](https://github.com/libjpeg-turbo/libjpeg-turbo) | IJG AND Zlib AND BSD-3-Clause | Homebrew `jpeg-turbo` |
| [pngquant](https://github.com/kornelski/pngquant) | GPL-3.0-or-later AND HPND AND BSD-2-Clause | Homebrew `pngquant` |
| [OxiPNG](https://github.com/shssoichiro/oxipng) | MIT | Homebrew `oxipng` |
| [libwebp](https://github.com/webmproject/libwebp) | BSD-3-Clause | Homebrew `webp` |

### High-Quality JPEG

| Tool | Licence | Installed |
| --- | --- | --- |
| [Google jpegli](https://github.com/google/jpegli) | BSD-3-Clause | Built from source at `031a0077f579` |

### Apple Photos

| Tool | Licence | Installed |
| --- | --- | --- |
| [ImageMagick](https://github.com/ImageMagick/ImageMagick) | ImageMagick | Homebrew `imagemagick` |
| [libheif](https://github.com/strukturag/libheif) | LGPL-3.0-or-later | Homebrew `libheif` |

### Photography

| Tool | Licence | Installed |
| --- | --- | --- |
| [ImageMagick](https://github.com/ImageMagick/ImageMagick) | ImageMagick | Homebrew `imagemagick` |
| [LibRaw](https://github.com/LibRaw/LibRaw) | LGPL-2.1-only OR CDDL-1.0 | Homebrew `libraw` |
| [libtiff](https://gitlab.com/libtiff/libtiff) | libtiff | Homebrew `libtiff` |
| [libheif](https://github.com/strukturag/libheif) | LGPL-3.0-or-later | Homebrew `libheif` |

### Animation

| Tool | Licence | Installed |
| --- | --- | --- |
| [FFmpeg](https://github.com/FFmpeg/FFmpeg) | GPL-3.0-or-later | Homebrew `ffmpeg` |
| [ImageMagick](https://github.com/ImageMagick/ImageMagick) | ImageMagick | Homebrew `imagemagick` |

### Legacy Formats

| Tool | Licence | Installed |
| --- | --- | --- |
| [ImageMagick](https://github.com/ImageMagick/ImageMagick) | ImageMagick | Homebrew `imagemagick` |

### Metadata Cleaner

| Tool | Licence | Installed |
| --- | --- | --- |
| [ExifTool](https://github.com/exiftool/exiftool) | Artistic-1.0-Perl OR GPL-1.0-or-later | Homebrew `exiftool` |
| [ImageMagick](https://github.com/ImageMagick/ImageMagick) | ImageMagick | Homebrew `imagemagick` |

### AI Provenance

| Tool | Licence | Installed |
| --- | --- | --- |
| [watermarks-remover](https://github.com/guillaumemeyer/watermarks-remover) | MIT | Built from source at `v0.5.0` |

### PDF Tools

| Tool | Licence | Installed |
| --- | --- | --- |
| [qpdf](https://github.com/qpdf/qpdf) | Apache-2.0 | Homebrew `qpdf` |
| [pdfcpu](https://github.com/pdfcpu/pdfcpu) | Apache-2.0 | Homebrew `pdfcpu` |
| [Ghostscript](https://github.com/ArtifexSoftware/ghostpdl-downloads) | AGPL-3.0-or-later | Homebrew `ghostscript` |

<!-- plugin-tools:end -->

## Licences of the engines

Stou's own code is under the [MIT licence](LICENSE). Each engine remains the work of its authors and is used under its own licence, shown in each plugin's table above as an SPDX expression; the authoritative terms are in each project's repository.

**Today** Stou does not bundle or redistribute any engine: when you enable a plugin it asks Homebrew to install the listed formulae, or builds the listed source revision on your Mac.

Permissive licences (MIT, BSD, Apache-2.0, IJG, libtiff, ImageMagick) ask nothing of Stou beyond their notices, which stay with each engine as Homebrew installs it. If Stou ever hosts prebuilt engine packages, that changes: GPL and AGPL engines would then need their source published with the package, so these notes would be revisited first.

## Roadmap

**Phase 1 — Stou Core.** Turn the operation-first utility into an intent-first app:
- Routines and a Processing Planner built on the existing capabilities
- Intent chosen before processing starts
- Folder, same-folder and clipboard delivery
- Managed staging and the lifecycle of temporary files
- Verification and clear processing states

Goal: everyday tasks need no codec or output settings.

**Phase 2 — Native Mac integration.** Finder Quick Actions, the Share sheet, a menu bar drop target, Shortcuts, favourite destinations, Custom Routines and a lightweight job history (no file copies).

**Phase 3 — Contextual agent.** Routine suggestions from context, destination-specific rules, saved workflows, real app and service integrations, and supervised automation of repeated jobs. All of it stays local-first, verified and consent-based.

Every feature has to pass one test: *does it help the user get from the file they have to a result ready for the next step, faster?* A feature that only adds another technical setting to the main screen works against the product.

## Install

Stou is meant to be installed by anyone, without Terminal. Homebrew is the other way, for people who already use it.

### Download the disk image (Today)

1. Download `Stou-….dmg` from the [latest release](https://github.com/prisonmike420/stou/releases/latest).
2. Open it: a window says **Drag. Drop. Done.** Drag **Stou** across the arrow onto **Applications**.
3. Open Stou from Applications. It is not signed yet, so the first time macOS blocks it: open System Settings › Privacy & Security and choose **Open Anyway**.

When an update is out, a blue **Update Stou** button appears in the rail above Settings, and **Update Stou** in the Help menu. It opens Settings, which says “Updating…” while the plugins' engines update, then, when Stou itself has a new release, shows the download with a **Cancel** button. Stou checks the download against the release's checksum and that it holds Stou of that version, replaces itself, quits and reopens as the new version. Settings, plugins and statistics stay. While a batch is running the button waits until it's done, because updating quits Stou.

If something goes wrong, Settings says what failed and links to the release page, and the old version stays as it was. Stou opened straight from the disk image can't replace itself: it asks you to drag it to Applications first.

Today plugins still install their engines through Homebrew, so without Homebrew Stou opens and checks for updates, but can't install a plugin yet.

**Planned:** plugins that install without Homebrew, and a signed, notarized app that opens without **Open Anyway**.

### Install with Homebrew (Today)

This repository is the Homebrew tap: its `Casks/stou.rb` downloads the ready-made `Stou.app` from the immutable GitHub Release ZIP, checks its SHA-256, and installs it in `/Applications` without compiling Swift locally. Every release updates it.

```zsh
brew tap prisonmike420/stou https://github.com/prisonmike420/stou
brew trust --cask prisonmike420/stou/stou
brew install --cask prisonmike420/stou/stou
```

The graphical app is the only interface for files and plugins. The terminal command is deliberately limited to Homebrew information and updates:

```zsh
stou info
stou update
stou app
```

Every time it starts, Stou asks GitHub for a newer release (otherwise at most once a day) and shows the **Update Stou** button. Installed through Homebrew, the button opens Terminal and hands the update to the installed `stou` helper. It upgrades the Cask, asks the running app to quit, waits for it to close, then opens the new bundle from `/Applications`. If the app does not close within ten seconds, it reports the recovery command instead of opening a second instance. If Homebrew installs nothing newer, it says so instead of reporting success. It never updates Homebrew or the app silently.

The current Cask is intentionally unsigned while the product is early. macOS may require the user to choose **Open Anyway** in Privacy & Security after installation. The release ZIP is still checksum-verified by Homebrew. Developer ID signing and notarization will remove that Gatekeeper step later.

### Coming from Rightform

Homebrew doesn’t follow a renamed repository by itself, and it asks you to trust a Cask under a new name, so Rightform’s update button can’t reach Stou on its own. Run these once:

```zsh
brew tap --custom-remote prisonmike420/rightform https://github.com/prisonmike420/stou
brew trust --cask prisonmike420/rightform/stou
brew upgrade --cask prisonmike420/rightform/rightform
```

The first points your tap at this repository, the second trusts the Cask under its new name, and the third installs Stou: the tap’s `cask_renames.json` turns the `rightform` Cask into `stou`, Homebrew replaces `Rightform.app` with `Stou.app`, and the `rightform` command becomes `stou`. Open Stou from `/Applications` afterwards; from then on its own update button works.

On its first launch Stou takes over Rightform’s settings and moves `~/Library/Application Support/Rightform` — plugins, statistics and pending results — to `…/Stou`, leaving a link at the old path for plugins built from source.

## Install from source

### Requirements

- macOS 26 or later
- Apple Command Line Tools or Xcode with a compatible macOS SDK
- [Homebrew](https://brew.sh/) — required only when installing a processing plugin

Clone the repository or download a source archive, then double-click `Install.command`.

It builds `Stou.app` locally, ad-hoc signs it, and replaces `~/Applications/Stou.app` only after a successful build. A failed compile does not replace an existing app.

On first launch, open Plugins in the rail and install the ones you need. Stou asks Homebrew to install the selected plugin's engines, then verifies them before making the capability available.

To remove the app bundle, run `Uninstall.command`. It deliberately leaves plugins, preferences and statistics in place.

## Versions and releases

Every commit to `main` is built and published by GitHub Actions ([`build.yml`](.github/workflows/build.yml)): a GitHub Release with the disk image and the ZIP Homebrew installs, and the updated `Casks/stou.rb` — pushed with a deploy key, the one thing allowed past `main`'s protection. Pull requests are built too, and `main` only accepts changes whose build passes.

The version series lives in [`VERSION`](VERSION). The first release of a series is that version; each later commit gets the next patch (`0.19.0`, `0.19.1`, `0.19.2`…). To start a new series, change `VERSION` in a pull request — a new minor version for new features or changed behaviour, `1.0.0` for the first stable release. The build number rises by itself: the version as a number plus the commit count (`0.19.0` → build `1900.41`).

## Safety model (today)

Stou follows a local inspect → process → verify → finalize flow.

- Originals are kept by default.
- If replacement is enabled, an original is changed only after output succeeds.
- Static optimization avoids saving a larger result by default.
- RAW files always create a derivative; they are never overwritten.
- PDF output is validated with the installed tools when PDF Tools is used.

These guarantees describe the current app. Stou is not a cloud processing or upload service: it works on the Mac.

## Project structure

Documents that aren't code — brand voice, App Store screenshots, how plugin monitoring works — are in [`docs/`](docs/README.md), with an index.

```text
Sources/App/                   app entry point, window and the Rightform migration
Sources/Engine/                detection, inspection, processing, PDF tools, plugins
Sources/Models/                settings, batch model, statistics, update checks
Sources/Views/                 workspace, settings and thumbnails (SwiftUI)
Resources/                     Info.plist and the plugins.json manifest
Resources/AppIcon.appiconset/  app icon source (Xcode asset); the build makes Stou.icns
brand/                         brand assets: master icon, social avatars, favicons
scripts/build-app.sh           reproducible app-bundle build
scripts/build-dmg.sh           the branded disk image, from a built app (needs dmgbuild)
scripts/update-plugin-tools.sh writes the README's plugin tools from plugins.json
Install.command                source installer
Uninstall.command              app-bundle removal
packaging/homebrew/            Cask template, cask_renames.json and the stou command
packaging/dmg/                 the disk image's background and window layout
docs/                          documents: brand voice, App Store screenshots, plugin monitoring
.github/workflows/             release build and weekly upstream plugin monitor
```

## License

[MIT](LICENSE)
