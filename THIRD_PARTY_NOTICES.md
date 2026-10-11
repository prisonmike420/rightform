# Third-party software

Stou's own code is covered by [LICENSE](LICENSE). Stou does **not** bundle, redistribute or re-sign the tools below. When you enable a plugin, Stou asks Homebrew to install the listed formulae, or builds the listed source revision locally on your Mac. Each tool remains the work of its authors and is used under its own licence.

Licence identifiers are SPDX expressions as published by the upstream project or its Homebrew formula. The authoritative terms are in each project's repository. The machine-readable source of this list is [`Resources/plugins.json`](Resources/plugins.json); keep the two in sync.

| Plugin | Component | Licence | Installed from | Project |
| --- | --- | --- | --- | --- |
| Compress Images | JPEG Archive | MIT | Homebrew `jpeg-archive` | https://github.com/danielgtaylor/jpeg-archive |
| Compress Images | libjpeg-turbo | IJG AND Zlib AND BSD-3-Clause | Homebrew `jpeg-turbo` | https://github.com/libjpeg-turbo/libjpeg-turbo |
| Compress Images | pngquant | GPL-3.0-or-later AND HPND AND BSD-2-Clause | Homebrew `pngquant` | https://github.com/kornelski/pngquant |
| Compress Images | OxiPNG | MIT | Homebrew `oxipng` | https://github.com/shssoichiro/oxipng |
| Compress Images | libwebp | BSD-3-Clause | Homebrew `webp` | https://github.com/webmproject/libwebp |
| Sharper JPEG | Google jpegli | BSD-3-Clause | Source, commit `031a007` | https://github.com/google/jpegli |
| Open HEIC & AVIF, Develop RAW, Optimize Animations, Convert Old Formats, Strip Metadata | ImageMagick | ImageMagick | Homebrew `imagemagick` | https://github.com/ImageMagick/ImageMagick |
| Open HEIC & AVIF, Develop RAW | libheif | LGPL-3.0-or-later | Homebrew `libheif` | https://github.com/strukturag/libheif |
| Develop RAW | LibRaw | LGPL-2.1-only OR CDDL-1.0 | Homebrew `libraw` | https://github.com/LibRaw/LibRaw |
| Develop RAW | libtiff | libtiff | Homebrew `libtiff` | https://gitlab.com/libtiff/libtiff |
| Optimize Animations | FFmpeg | GPL-3.0-or-later (Homebrew build) | Homebrew `ffmpeg` | https://github.com/FFmpeg/FFmpeg |
| Strip Metadata | ExifTool | Artistic-1.0-Perl OR GPL-1.0-or-later | Homebrew `exiftool` | https://github.com/exiftool/exiftool |
| Check AI Labels | watermarks-remover | MIT | Source, tag `v0.5.0` | https://github.com/guillaumemeyer/watermarks-remover |
| Shrink PDFs | qpdf | Apache-2.0 | Homebrew `qpdf` | https://github.com/qpdf/qpdf |
| Shrink PDFs | pdfcpu | Apache-2.0 | Homebrew `pdfcpu` | https://github.com/pdfcpu/pdfcpu |
| Shrink PDFs | Ghostscript | AGPL-3.0-or-later | Homebrew `ghostscript` | https://github.com/ArtifexSoftware/ghostpdl-downloads |

## If Stou ever ships prebuilt plugin archives

The `artifact` field in `Resources/plugins.json` allows Stou to download a prebuilt plugin package. Publishing such a package is redistribution and changes the obligations above. In particular, pngquant and the Homebrew build of FFmpeg are GPL-3.0-or-later and Ghostscript is AGPL-3.0-or-later: a package that contains them must ship the licence texts and offer the corresponding source. LGPL components (libheif, LibRaw) must remain replaceable. Do not publish an `artifact` until the package includes these notices and sources.
