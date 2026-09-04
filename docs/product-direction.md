# RIGHTFORM product direction

This document records the intended v1 product and interface direction. It is not an implementation specification and does not change the capabilities advertised for the current release.

## Product idea

Rightform should make files ready for their next use. Rather than asking the user to configure codecs, compression levels or conversion pipelines, it should ask what needs to happen next and carry out the work safely.

**Design principle:** expose intent and hide implementation.

The current application already supplies useful foundations: local processing, inspection, verification, safe replacement, RAW preservation and a compact single-window workflow.

## Voice and naming

- Use **RIGHTFORM** for the wordmark and **Rightform** in normal text.
- Primary line: **Files, ready for what’s next.**
- Prefer direct operational language: **What’s next?**, **Ready for Web**, **Where to?**, **Keep originals**, **Done**.
- Do not lead the primary UI with *AI*, *optimizer*, *converter*, *compress*, codec names or numeric quality settings.
- Show concrete progress, not anthropomorphic claims: `Preparing 18 files for Web` and `6 of 18` are preferable to claims about “intelligent” processing.

The name is not confirmed as legally clear. A professional trademark clearance in relevant software classes, plus domain and handle checks, is required before a commercial launch or trademark filing.

## Interface principles

- Keep the existing 620 × 620 single-window, drop-first interaction.
- Keep idle state minimal: wordmark, **Drop files**, and the formats currently available on that Mac.
- Use native macOS materials, system accent colour and SF Pro in the app.
- Avoid futuristic gradients, literal compression imagery and feature-card dashboards.
- The icon concept is **Fit**: an object becoming the appropriate form for its destination. It should not be a file glyph, RF monogram, wand, robot or before/after image pair.

## Proposed v1 workflow

```text
drop files
→ What’s next? (Routine)
→ Where to? (Delivery)
→ prepare and verify
→ deliver
→ apply retention policy
```

### Routine — why a file is being prepared

| Routine | Default priority |
| --- | --- |
| Share | Compatibility, visual quality and reasonable size |
| Web | Suitable dimensions, web-friendly format, sRGB and cleanup |
| Mail | A reasonable size with broad compatibility |
| Print | Resolution, profile and quality first |
| Archive | Preservation first |
| Custom | Explicit user-defined rules |

A routine is not a raw encoder preset. It represents an outcome; its underlying settings remain inspectable in **Details** or **Advanced Processing**.

### Delivery — where the result goes

Initial delivery options should be:

- Copy
- Share…
- Same folder
- Choose folder…
- Favourite folders

Specific app integrations are future work, not a v1 promise.

### Afterwards — what stays

Retention must be explicit and only happen after a verified delivery:

- Keep originals
- Move originals to Trash after successful delivery
- Keep prepared files
- Clear temporary files

Clipboard and share workflows should avoid creating unnecessary `_compressed` files in a user’s folders.

## Settings hierarchy

As routines are implemented, the primary Settings structure should become:

```text
ROUTINES
DELIVERY
PROCESSING — Advanced
EXTENSIONS
STATISTICS
```

Format-specific controls such as JPEG quality, progressive output or PNG lossy mode belong in Advanced Processing. They remain valuable for Custom routines and expert use, but should not be the main interaction model.

## What is not implemented yet

- Routine selection and its processing policies
- Delivery destinations, favourites and clipboard/share delivery
- Retention policies beyond the current output and original-file controls
- The Fit icon and a custom RIGHTFORM wordmark
- The reorganized Settings hierarchy

Future implementation should preserve the existing verification-first behavior and distinguish processing intent from delivery destination.
