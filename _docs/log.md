# Log

`/log/` is a single timeline of everything dated on the site, grouped by
day with one page per month, starting January 2026 (`START_DATE` in the
plugin). `/log/` holds the most recent month; older
months live at `/log/YYYY/MM/`. Only months with entries get a page.

Built by `_plugins/log.rb` (a generator — no front matter page in
`pages/`), rendered by `_includes/log-month.html` as one `<article>` per
day, with one sentence per kind ("Listened to A by X and B by Y.").
Only posts and photos link (to their own pages); nothing links out. `_includes/log-join.html` supplies the ", " / " and "
separators.

Sources: `_posts/`, `_photos/`, `_data/media.json` (film, tv, music),
`_data/cinema.json` (marks films seen at the cinema),
`_data/concerts.json`, `_data/grounds.json`, `_data/flights.json`.
`collect` normalizes each into an item with `kind`, `emoji`, `date`
(`YYYY-MM-DD`) and kind-specific fields; `day` then groups a day's items
(TV episodes per show, concerts per venue, albums and films deduped). A
new source needs both a `collect` entry and a sentence in the template.

Markup is `h-feed` / `h-entry` so IndieWeb readers can follow the page.

Plugins aren't reloaded by `jekyll serve` — restart it after editing the
plugin.

## Cinema

`_data/cinema.json` lists cinema visits, maintained by hand (Letterboxd
tags aren't in the RSS feed). Each entry: `date`, `title`, `year`, and
the Letterboxd `guid` of the matching `media.json` film entry — matching
is by `guid` only, since titles can differ. Matched films read "Watched
… at the cinema." on `/log/` and get 🍿 instead of 🎬 on `/media/`.
