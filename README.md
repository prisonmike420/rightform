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

A narrow rail on the left is always visible: **Home**, **Plugins** — a catalogue of every plugin where you install, open, configure or remove them — your installed plugins as workspaces, pinned ones first (right-click a plugin to pin it), and **Settings** at the bottom. Names show on hover. Settings is one page with the theme, originals and where files are saved, and About: version, update check, usage so far and links to support, release notes and the source code. It also opens from Stou › Settings… (⌘,). While a newer version exists, a coloured update button sits above Settings.

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

\* Only with the Metadata Cleaner plugin installed; otherwise the routine says so and keeps them.

A routine sets quality, size, format, colour and hidden details, and plans each file: on a website photos become WebP while screenshots and graphics stay PNG; for chats and email, HEIC and AVIF become JPEG; for print and keeping, formats never change. The finer per-format controls stay on each plugin's page.

### Where to? and afterwards

After choosing what to do, every job asks where the results go — nothing is carried over from the last one:

- **Next to the originals**, named with the suffix from Settings (`photo_prepared.jpg`).
- **A favourite folder** (set in Settings) or **Choose Folder…** for this job.
- **Copy** — the files go on the clipboard, ready to paste into a chat, an email or Finder.
- **Share…** — the macOS Share sheet: Mail, Messages, AirDrop and more.

**Afterwards:** originals stay unless you turn on *Move originals to the Trash* — and then only after each new file is saved and checked. RAW originals always stay; copied or shared files never trash their originals.

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
- Handles files dropped onto the window, selected in the file picker and found recursively in folders.
- Resizes without upscaling; can convert output formats and prepare colour for sharing.
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
| Animation | GIF, APNG, Animated WebP | Plugin |
| Legacy formats | BMP, TGA, PCX, PICT, PNM, XBM, XPM, SGI, Sun Raster | Plugin |
| Metadata Cleaner | Metadata removal for supported images | Plugin |
| AI Provenance | Experimental; off unless explicitly enabled | Plugin |
| PDF Tools | PDF compression and duplicate-page analysis | Plugin |

Plugins are optional and are installed from Plugins in the rail. Each one brings only the engines it needs. The app installs no image or PDF engines until you select a plugin.

The engines are open-source projects by other authors. Stou installs them through Homebrew or builds a pinned upstream revision locally; it does not bundle, modify or re-sign them. Each plugin page in Settings lists its components with licence and installed version, and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) has the full list.

If a Routine needs a capability that is not installed, Stou will say what is missing and offer to install it. It will not deliver a partial result as if it met the Routine.

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

## Install with Homebrew

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

After a published GitHub Release, Stou checks for a newer version and shows an **Update to …** button. The button opens Terminal and hands the update to the installed `stou` helper. It upgrades the Cask, asks the running app to quit, waits for it to close, then opens the new bundle from `/Applications`. If the app does not close within ten seconds, it reports the recovery command instead of opening a second instance. If Homebrew installs nothing newer, it says so instead of reporting success. It never updates Homebrew or the app silently.

The current Cask is intentionally unsigned while the product is early. macOS may require the user to choose **Open Anyway** in Privacy & Security after installation. The release ZIP is still checksum-verified by Homebrew. Developer ID signing and notarization will remove that Gatekeeper step later.

### Coming from Rightform

Rightform’s update button, or `rightform update`, installs Stou: the tap’s `cask_renames.json` turns the `rightform` Cask into `stou`, Homebrew replaces `Rightform.app` with `Stou.app`, and the `rightform` command becomes `stou`. Open Stou from `/Applications` afterwards.

On its first launch Stou takes over Rightform’s settings and moves `~/Library/Application Support/Rightform` — plugins, statistics and pending results — to `…/Stou`, leaving a link at the old path for plugins built from source.

If Homebrew still shows Rightform 0.17 or older, the tap points at the removed `homebrew-rightform` repository. Point it here once, then update:

```zsh
brew tap --custom-remote prisonmike420/rightform https://github.com/prisonmike420/stou
brew upgrade --cask stou
```

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

Every commit to `main` is built and published by GitHub Actions ([`build.yml`](.github/workflows/build.yml)): a GitHub Release with the ZIP Homebrew installs, and the updated `Casks/stou.rb` — pushed with a deploy key, the one thing allowed past `main`'s protection. Pull requests are built too, and `main` only accepts changes whose build passes.

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

```text
Sources/App/                   app entry point, window and the Rightform migration
Sources/Engine/                detection, inspection, processing, PDF tools, plugins
Sources/Models/                settings, batch model, statistics, update checks
Sources/Views/                 workspace, settings and thumbnails (SwiftUI)
Resources/                     Info.plist and the plugins.json manifest
Resources/AppIcon.appiconset/  app icon source (Xcode asset); the build makes Stou.icns
brand/                         brand assets: master icon, social avatars, favicons
scripts/build-app.sh           reproducible app-bundle build
Install.command                source installer
Uninstall.command              app-bundle removal
packaging/homebrew/            Cask template, cask_renames.json and the stou command
docs/plugin-monitoring.md      upstream plugin version monitoring
.github/workflows/             release build and weekly upstream plugin monitor
```

## License

[MIT](LICENSE)
