# Photos

## How It Works

Photos are a Jekyll collection in `_photos/`. Each entry is a Markdown file with front matter only (no body content). The feed page (`pages/photos.md`) renders the 50 most recent entries using `_includes/photos-feed.html`.

## Front Matter Fields

Required: `date`, `time`, `title`, `alt`, `image`, `width`, `height`
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

## Responsive Image Markup

Feed images use `srcset` with the 480/720/960/1280 variants and `sizes="(max-width: 48rem) 100vw, calc(72ch + 3rem)"`.

- First image: `loading="eager"` + `fetchpriority="high"`
- All other images: `loading="lazy"`
- All images: `decoding="async"`

The date links to the photo detail page; the image itself is not linked.

## Theming & Indexing

- The photos feed page forces `theme: sand` (lightest background).
- Individual photo pages use `_layouts/photo.html`, default to `theme: sand` via `_config.yml` defaults, and are set `robots: noindex`.

## Feeds

- `/photos.xml` — Atom feed at the root, linked in the global `<head>`, embeds the 720px variant.
