# RIGHTFORM

**Files, ready for what’s next.**

Rightform is a native macOS app that prepares files for their next use — locally, safely and without asking you to think about codecs.

You hand Rightform your files and say what they are for: a website, an email, a chat, print or an archive. Rightform works out the right processing for each file, does it, verifies the result and delivers it where you need it. Afterwards it keeps only what you actually want to keep.

**You decide the goal. Rightform decides the method.**

> **Project status:** Rightform is the renamed continuation of IMGLESS; the version is in [`VERSION`](VERSION). Routines are in the app; per-file planning, delivery destinations and retention are the product target and are being built in phases. Sections marked **Today** describe shipped behaviour; sections marked **Planned** do not.

## The idea

Someone with 40 photos for a website should not have to decide on resolution, WebP vs JPEG, ICC profiles, sRGB, EXIF, compression levels, output folders and leftover copies. Their actual task is “get these photos ready for the site”.

Every Rightform job answers four questions:

| Question | Meaning | Example |
| --- | --- | --- |
| **What?** | The files you brought | 18 photos |
| **What’s next?** | Why they are being prepared — the *Routine* | Web |
| **Where to?** | Where the result goes — *Delivery* | Website Assets |
| **Afterwards?** | What stays once it is delivered — *Retention* | Keep originals |

Rightform turns those answers into a per-file processing plan. One Routine does not mean one operation: in a single Web batch a PNG may become WebP, a JPEG may be resized, a screenshot with transparency may stay PNG, and a file that already fits is left alone as **Already ready**.

### Routines

A narrow rail on the left is always visible: **Home**, **Plugins** — a catalogue of every plugin where you install, open, configure or remove them — your installed plugins as workspaces, pinned ones first (right-click a plugin to pin it), and **Settings** at the bottom. Names show on hover. Settings is one page with the theme, originals and where files are saved, and About: version, update check, usage so far and links to support, release notes and the source code. It also opens from Rightform › Settings… (⌘,). While a newer version exists, a coloured update button sits above Settings.

- **Home** takes any supported file. It shows what was added and what can be done with it — the routines below, or an installed plugin that takes all of the files — and nothing changes until you choose.
- **A plugin's workspace** does that plugin's one job, for example Metadata Cleaner removes hidden details and PDF Tools makes PDFs lighter. It takes only that plugin's formats and leaves everything else about the files as it was.

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

## What Rightform is not

Rightform is not a file manager, a photo library, a photo or RAW editor, a cloud service, a chatbot, or a panel of encoder settings. It is the layer between the file you have and the next thing you do with it.

## Principles

- **Local-first.** Processing happens on the Mac. No account, no uploads. Any future cloud destination will need separate, explicit consent.
- **Minimal intervention.** Rightform doesn’t convert a file just because it can. A file that already fits is passed through unchanged.
- **Verify before delivering.** Output is decoded and checked against the plan. A file that fails verification is never presented as a success.
- **No silent loss.** Rightform asks first before anything significant changes: lost transparency, removed metadata, lower resolution, lost selectable text in a PDF, rasterization, removed pages or a removed original.
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

The engines are open-source projects by other authors. Rightform installs them through Homebrew or builds a pinned upstream revision locally; it does not bundle, modify or re-sign them. Each plugin page in Settings lists its components with licence and installed version, and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) has the full list.

If a Routine needs a capability that is not installed, Rightform will say what is missing and offer to install it. It will not deliver a partial result as if it met the Routine.

## Roadmap

**Phase 1 — Rightform Core.** Turn the operation-first utility into an intent-first app:
- Routines and a Processing Planner built on the existing capabilities
- Intent chosen before processing starts
- Folder, same-folder and clipboard delivery
- Managed staging and the lifecycle of temporary files
- Verification and clear processing states

Goal: everyday tasks need no codec or output settings.

**Phase 2 — Native Mac integration.** Finder Quick Actions, the Share sheet, a menu bar drop target, Shortcuts, favourite destinations, Custom Routines and a lightweight job history (no file copies).

**Phase 3 — Contextual agent.** Routine suggestions from context, destination-specific rules, saved workflows, real app and service integrations, and supervised automation of repeated jobs. All of it stays local-first, verified and consent-based.

Every feature has to pass one test: *does it help the user get from the file they have to a result ready for the next step, faster?* A feature that only adds another technical setting to the main screen works against the product.

## Install from source

### Requirements

- macOS 26 or later
- Apple Command Line Tools or Xcode with a compatible macOS SDK
- [Homebrew](https://brew.sh/) — required only when installing a processing plugin

Clone the repository or download a source archive, then double-click `Install.command`.

It builds `Rightform.app` locally, ad-hoc signs it, and replaces `~/Applications/Rightform.app` only after a successful build. A failed compile does not replace an existing app.

On first launch, open Plugins in the rail and install the ones you need. Rightform asks Homebrew to install the selected plugin's engines, then verifies them before making the capability available.

To remove the app bundle, run `Uninstall.command`. It deliberately leaves plugins, preferences and statistics in place.

## Homebrew

The official Cask lives in the [homebrew-rightform](https://github.com/prisonmike420/homebrew-rightform) tap. It downloads the ready-made `Rightform.app` from the immutable GitHub Release ZIP, checks its SHA-256, and installs it in `/Applications` without compiling Swift locally.

Install Rightform with:

```zsh
brew trust --cask prisonmike420/rightform/rightform
brew install --cask prisonmike420/rightform/rightform
```

If you installed an older source-building Formula, migrate once:

```zsh
brew uninstall rightform
brew trust --cask prisonmike420/rightform/rightform
brew install --cask prisonmike420/rightform/rightform
```

The graphical app is the only interface for files and plugins. The terminal command is deliberately limited to Homebrew information and updates:

```zsh
rightform info
rightform update
rightform app
```

After a published GitHub Release, Rightform checks for a newer version and shows an **Update to …** button in the top-right corner of the window. The button opens Terminal and hands the update to the installed `rightform` helper. It upgrades the Cask, asks the running app to quit, waits for it to close, then opens the new bundle from `/Applications`. If the app does not close within ten seconds, it reports the recovery command instead of opening a second instance. It never updates Homebrew or the app silently.

The current Cask is intentionally unsigned while the product is early. macOS may require the user to choose **Open Anyway** in Privacy & Security after installation. The release ZIP is still checksum-verified by Homebrew. Developer ID signing and notarization will remove that Gatekeeper step later.

## Versions and releases

The version lives in [`VERSION`](VERSION) and nowhere else: `scripts/build-app.sh` writes it into the app, and the build number rises by itself — the version as a number plus the commit count (`0.18.0` → build `1800.38`).

To publish a release from an up-to-date `main`:

```zsh
scripts/release.sh minor
```

It raises the version (`patch` for fixes, `minor` for new features or changed behaviour, `major` for the first stable release), commits and tags it, builds the ZIP Homebrew installs, creates the GitHub Release with the changes since the last one, and updates the Cask and the local tap.

## Safety model (today)

Rightform follows a local inspect → process → verify → finalize flow.

- Originals are kept by default.
- If replacement is enabled, an original is changed only after output succeeds.
- Static optimization avoids saving a larger result by default.
- RAW files always create a derivative; they are never overwritten.
- PDF output is validated with the installed tools when PDF Tools is used.

These guarantees describe the current app. Rightform is not a cloud processing or upload service: it works on the Mac.

## Project structure

```text
Sources/App/                 app entry point and window
Sources/Engine/              detection, inspection, processing, PDF tools, plugins
Sources/Models/              settings, batch model, statistics, update checks
Sources/Views/               workspace, settings and thumbnails (SwiftUI)
Resources/                   app metadata, icon and plugins.json manifest
scripts/build-app.sh         reproducible app-bundle build
Install.command              source installer
Uninstall.command            app-bundle removal
packaging/homebrew/          Homebrew Cask template and release notes
docs/plugin-monitoring.md    upstream plugin version monitoring
.github/workflows/           weekly upstream plugin monitor
```

## License

[MIT](LICENSE)
