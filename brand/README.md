# Stou brand assets

The Stou icon is **The Well, Blue #1**: a cobalt tile with a deep square well
to drop things into. The blue is Klein-inspired cobalt/ultramarine
(`#0826E1` as a web theme colour), not a measured International Klein Blue.

All files are raster exports of one artwork; there is no vector source.

<p align="center"><img src="preview/stou-assets-overview.jpg" alt="The Stou icon as a macOS icon, a social avatar and a favicon"></p>

## The app icon

The app's icon lives in [`Resources/AppIcon.appiconset`](../Resources/AppIcon.appiconset),
a standard Xcode asset with every macOS size. It is the only source:
`scripts/build-app.sh` turns it into `Stou.icns` when it builds the app, so no
`.icns` is kept in the repository. To change the icon, replace those PNGs at
the same sizes and names.

## In this folder

| Path | What it is |
| --- | --- |
| `icon/stou-icon-1024.png` | Master icon, 1024 × 1024, transparent background. Use this wherever the icon appears on its own. |
| `icon/stou-icon-1024-offwhite.png` | The same icon flattened onto off-white, for previews only. Never use it as an app icon. |
| `social/stou-avatar-light-{1024,512}.png` | Primary square avatar on a light background; safe for round crops. |
| `social/stou-avatar-blue-{1024,512}.png` | Alternative avatar: light plate on blue. |
| `favicon/` | Website icons: `favicon.ico` (16, 32, 48 px), PNGs from 16 to 512 px, a 180 px opaque `apple-touch-icon.png` and a sample `site.webmanifest`. |
| `preview/stou-assets-overview.jpg` | Overview of the icon at app, avatar and favicon size. |

For a website, copy `favicon/` to the site root and add:

```html
<link rel="icon" href="/favicon.ico" sizes="any">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
```

## Notes

- The icon fills more of its canvas than Apple's macOS grid (about 926 of
  1024 px against roughly 824), so it reads slightly larger than other icons
  in the Dock.
- Small sizes are downsampled from the master; check them in the Dock,
  Finder and a browser tab.
- The icons have not been through App Store Connect validation.
