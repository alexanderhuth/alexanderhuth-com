# Photos

## How It Works

Photos are a Jekyll collection in `_photos/`. Each entry is a Markdown file with front matter only (no body content). The feed page (`pages/photos.md`) renders the 50 most recent entries using `_includes/photos-grid.html`.

## Front Matter Fields

Required: `date` (full datetime with timezone), `time`, `title`, `alt`, `image`, `width`, `height`
Optional: `location`, `robots`

## Image Files

Store files at each size in the corresponding directory:

| Size | Directory | Used for |
|---|---|---|
| 1920px | `/images/` | Detail page |
| 1280px | `/images/1280/` | Feed (largest srcset step) |
| 960px | `/images/960/` | Feed srcset |
| 720px | `/images/720/` | Feed srcset; Atom feed embed |
| 480px | `/images/480/` | Feed srcset (smallest) |

## Generating the Variants

Drop the photo into `images/` under its intended filename, then:

```bash
scripts/photo-sizes.sh images/<filename>.jpg
```

The script writes all five sizes, replaces `images/<filename>.jpg` with the 1920px version, and prints the `image`, `width`, and `height` values for the front matter. Variants are stripped of EXIF, progressive, 4:2:0 subsampled, with quality rising by size (82, 84, 86, 88, 92). Steps larger than the source are skipped rather than upscaled.

It also reads `DateTimeOriginal` from the source before stripping EXIF and prints a ready-made `date` and `time`, rounded up to the next five minutes. The UTC offset is the one in effect locally on that date, so photos taken in another timezone need the offset corrected by hand.

## Responsive Image Markup

Feed images use `srcset` with the 480/720/960/1280 variants and `sizes="(max-width: 48rem) 100vw, calc(72ch + 3rem)"`.

Sizes bound the **long edge**, so a portrait file is narrower than its step name — a 1440x1920 photo yields 360px at the 480 step. `photo-figure.html` and `photos-grid.html` therefore compute each `srcset` descriptor from the front matter `width`/`height` rather than hardcoding the step name. Accurate `width`/`height` values are what make the whole thing work.

- First image: `loading="eager"` + `fetchpriority="high"`
- All other images: `loading="lazy"`
- All images: `decoding="async"`

The date links to the photo detail page; the image itself is not linked.

## Theming & Indexing

- The photos feed page forces `theme: sand` (lightest background).
- Individual photo pages use `_layouts/photo.html`, default to `theme: sand` via `_config.yml` defaults, and are set `robots: noindex`.

## Feeds

- `/photos.xml` — Atom feed at the root, linked in the global `<head>`, embeds the 720px variant.
