---
name: add-photo
description: Add a new photo entry to the `_photos/` collection in this Jekyll site. Use when the user wants to publish a new photo, has image files ready to place, or needs help writing front matter for a photo.
---

# Add Photo

Use this skill to add a new photo to the `_photos/` Jekyll collection. A complete photo entry requires both a Markdown file in `_photos/` and image files at five sizes in the `images/` directory tree.

## When To Use It

- The user wants to publish a new photo to the feed.
- The user wants to write or review the front matter for a photo entry.
- The user needs a reminder of the image size requirements.

## Markdown File

Create one file in `_photos/` named with a kebab-case slug (e.g., `my-photo-title.md`). The file contains **front matter only** — no body content.

```yaml
---
layout: photo
title: "Photo Title"
robots: noindex
date: YYYY-MM-DD HH:MM:00 +02:00
time: "HH:MM"
image: /images/slug.jpg
width: 1920
height: 1280
alt: "Descriptive alt text for the photo."
location: "Location name"
---
```

### Field Reference

| Field | Required | Notes |
|---|---|---|
| `layout` | yes | Always `photo` |
| `title` | yes | Short, descriptive title |
| `robots` | yes | Always `noindex` |
| `date` | yes | Full datetime with timezone: `YYYY-MM-DD HH:MM:00 +02:00` (use `+01:00` in winter / CET, `+02:00` in summer / CEST). The feed sorts by `date` descending, so the time component must be correct. |
| `time` | yes | `"HH:MM"` — displayed in the photo detail page and feed caption |
| `image` | yes | Path to the 1920px image: `/images/slug.jpg` |
| `width` | yes | Width of the 1920px source image in pixels |
| `height` | yes | Height of the 1920px source image in pixels |
| `alt` | yes | Descriptive alt text; also used in Atom feed |
| `location` | no | Where the photo was taken |

- The slug in the filename, the `image` path, and all size-variant filenames must match exactly.
- The `time` field must be in `"HH:MM"` format (quoted string).
- Portrait images are typically 1280×1920; landscape images are typically 1920×1079 or similar.

## Image Files

Five sizes are required. Place each file in the corresponding directory using the same slug:

| Size | Directory | Used for |
|---|---|---|
| 1920px wide | `/images/` | Detail page |
| 1280px wide | `/images/1280/` | Feed (largest srcset step) |
| 960px wide | `/images/960/` | Feed srcset |
| 720px wide | `/images/720/` | Feed srcset + Atom feed embed |
| 480px wide | `/images/480/` | Feed srcset (smallest) |

Example for slug `sunset-over-berlin`:
```
images/sunset-over-berlin.jpg
images/1280/sunset-over-berlin.jpg
images/960/sunset-over-berlin.jpg
images/720/sunset-over-berlin.jpg
images/480/sunset-over-berlin.jpg
```

If the user provides a single source image, remind them that the five size variants must be generated before the photo will render correctly at all breakpoints. ImageMagick can resize them:

```bash
# Run from the repo root — replace SLUG and adjust the source path
SLUG=my-photo-title
SRC=~/Desktop/${SLUG}.jpg
convert "$SRC" -resize 1920x images/${SLUG}.jpg
convert "$SRC" -resize 1280x images/1280/${SLUG}.jpg
convert "$SRC" -resize 960x  images/960/${SLUG}.jpg
convert "$SRC" -resize 720x  images/720/${SLUG}.jpg
convert "$SRC" -resize 480x  images/480/${SLUG}.jpg
```

## Workflow

1. Ask the user for the photo details if any required fields are missing: title, date, time, dimensions, alt text, and optionally location.
2. Derive the kebab-case slug from the title (lowercase, spaces → hyphens, remove special characters).
3. Create `_photos/<slug>.md` with the correct front matter.
4. Confirm which image size variants are already in place; if any are missing, show the ImageMagick commands above.
5. Verify the front matter `width` and `height` match the actual 1920px file dimensions. If the user hasn't confirmed dimensions, note that they should double-check.

## Response Pattern

After creating the file, report:

1. The filename created and its URL path (`/photos/<slug>/`).
2. Which image files are present vs. missing (check all five directories).
3. Any fields that were left with placeholder values and still need the user's input.
