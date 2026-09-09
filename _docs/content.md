# Content

## File Locations

- `_posts/` — blog posts (`YYYY-MM-DD-title.md`, `layout: post`)
- `pages/` — all other pages (`layout: page`)
- `_photos/` — photo collection entries
- `_shirts/` — shirt collection entries
- `_data/` — JSON data files consumed by Liquid templates

## File Naming

- Pages: `kebab-case.md`
- Posts: `YYYY-MM-DD-kebab-case.md`
- Includes: `kebab-case.html`
- Layouts: `kebab-case.html`

## Front Matter

Required fields: `layout`, `title`

Optional fields:
- `description` — meta description
- `seo_title` — override title for SEO
- `permalink` — custom URL path
- `robots: noindex` — prevent indexing
- `theme` — force a specific theme (e.g. `theme: sand`)

## Shirts Collection

`_shirts/` holds one document per shirt, rendered as the flip-tile grid
on `/shirts/` (`output: false` — no per-shirt pages). The filename is the
image slug (`images/shirts/<slug>.jpg`, long edge 960 — the largest size
kept in the repo; larger originals live outside it — with `480/` and
`720/` variants).
Front matter: `title` (the plain band/festival name, shown on the tile's
flip card), `image`, `width`/`height` (of that 960 file), `alt` (the full
shirt description), and `order` (grid position, spaced by 10). A shirt
photographed from both sides is one document: `back`/`back_alt` name the
back-side image (same dimensions as the front), which the flip shows
under the label scrim in place of the front. The
document body is the shirt's note in the page's Notes section, printed
under a `###` heading of the shirt's `title`; leave it empty for shirts
without one, and don't repeat the name in the note. Only one document
per band should carry a note.

## Markdown

- Line length: ~72 characters
- Use `#` for h1, `##` for subheadings
- Use absolute URLs for internal links (`/page-name/`)
- Include alt text for all images

## Layouts & Includes

Layout shell structure:

```html
{% include html-start.html %}
  {% include html-head.html %}
  <body>
    {% include header.html %}
    <main role="main">
      {{ content }}
    </main>
    {% include footer.html %}
  </body>
{% include html-end.html %}
```

Use semantic HTML5 elements and include proper ARIA labels.

## Data Files (JSON)

Stored in `_data/`. The concerts schema:

```json
{
  "setlist_id": "unique_id",
  "date": "YYYY-MM-DD",
  "artist": "Artist Name",
  "venue": "Venue Name",
  "city": "City",
  "country": "Country",
  "festival": null,
  "setlist_url": "https://example.com"
}
```

Keep nullable fields `null` rather than inventing values.
