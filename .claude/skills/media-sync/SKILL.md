---
name: media-sync
description: Run the media sync for this Jekyll site when the user wants to import new listening or watching activity into `_data/media.json`, or troubleshoot the Ruby sync workflow in `sync_media.rb`.
compatibility: Requires Ruby 3.4+. Run from the Jekyll repo root. Needs internet access for Record Club RSS, Last.fm API, Letterboxd RSS, and MusicBrainz. Last.fm fallback requires LASTFM_API_KEY in `.env`.
---

# Media Sync

Use this skill to import new media activity. It runs `sync_media.rb`, which updates `_data/media.json` from Record Club (primary), Last.fm (fallback), and Letterboxd sources.

## When To Use It

- The user wants to sync new media activity.
- The user wants to debug why the media sync failed.
- The user wants to understand which files, env vars, or scripts are involved.

## Output Schema

The canonical media data is structured, not display-string based.

- Films: `title`, `year`, `director`
- Music: `album`, `artist`, `year`
- TV: `show_title`, `season_number`, `episode_number`, `episode_title`
- Shared fields: `type`, `emoji`, `date`, `date_display`, `month`, `pub_ts`
- Optional sync/provenance fields: `guid`, `source`, `url`, `set_track_count`, `set_start_uts`, `set_end_uts`

Do not treat `lead` or `meta` as canonical fields.

See [docs/media-sync.md](../../../docs/media-sync.md) for sources, schema, and deduplication reference.

## Inputs And Dependencies

- Run from the repository root.
- Expected env file: `.env`
- Required env vars:
  - `LASTFM_API_KEY` — only needed when Last.fm fallback fires
  - `SERIALIZD_TOKEN` — JWT for the Serializd diary API (optional; fall back to user paste if absent)
- Primary entrypoint: `scripts/sync_media.rb`
- Secondary scripts (same `scripts/` folder):
  - `scripts/sync_recordclub.rb` — Record Club RSS (primary music source)
  - `scripts/sync_lastfm.rb` — Last.fm API (fallback when Record Club returns no new entries)
  - `scripts/sync_letterboxd.rb` — Letterboxd RSS (films)
  - `scripts/musicbrainz.rb` — shared MusicBrainz lookup utilities

## Workflow

1. Inspect the current worktree before running. `_data/media.json` is expected to change; note any unrelated edits already present.

2. Read the existing recent entries before syncing. Treat `_data/media.json` as the first source of truth for known years, directors, and previously imported items.
   - The JSON shape is `{ "entries": [...] }`.
   - The `month` field is a label such as `"April 2026"`, not `"2026-04"`.

3. **Always fetch new TV entries from the Serializd diary** — do this every time, even if the user didn't mention it.
   - If `SERIALIZD_TOKEN` is set in `.env`, call the API directly (see **Serializd Diary API** below). Page through until you've seen entries already present in `media.json`.
   - If the token is absent or the API is unreachable, ask the user to paste new entries from [their Serializd diary](https://www.serializd.com/user/alexanderh/diary).
   - Treat API results or the user's pasted list as source data for manual TV updates to `_data/media.json`.

4. Run the sync from the repo root:

```bash
ruby .claude/skills/media-sync/scripts/sync_media.rb
ruby .claude/skills/media-sync/scripts/sync_media.rb --dry-run
```

5. Review the output summary from the Ruby scripts.

6. Inspect the resulting diff in `_data/media.json` and identify genuinely new entries.

7. Resolve missing metadata after the sync:
   - Reuse existing values from `_data/media.json` first.
   - For any newly added film entry whose `director` is still null, do a web search using the title and year.
   - Use primary or otherwise authoritative sources. Do not trust RSS-level film-director fields or feed-author fields as director data.
   - Patch `_data/media.json` with the confirmed director and cite the source in the response.
   - If the director still cannot be verified, leave it null and say so explicitly.

8. If the user supplied new Serializd diary entries, add the missing TV rows to `_data/media.json` without duplicating existing watches.

## Entry Ordering Rules

All entries have a `pub_ts` field. The template sorts by `date` descending (primary), then `pub_ts` descending within each date — do not manually reorder entries in the JSON.

**`pub_ts` must be assigned correctly when adding TV entries manually:**
- Serializd pastes newest-first, so assign descending `pub_ts` values in paste order.
- TV `pub_ts` must be higher than the highest non-TV `pub_ts` on the same date, so TV appears above albums and films for that day.
- If non-TV entries exist on that date: `base = max_non_tv_pub_ts + (entry_count * 60)`, then subtract 60 per entry in paste order.
- If no non-TV entries exist on that date: `base = date_midnight_utc + 86399`, then subtract 60 per entry in paste order.

## Deduplication Rules

- Do not create duplicates for entries already present in `media.json`.
- Only add a new row when the media was actually consumed as a distinct event.
- For music, repeat listens of the same album are valid when the underlying listen window is different.
- For films and TV, use the existing item identity and date data to avoid duplicate rows for the same watch.
- `sync_media.rb` runs `dedupe_tv.rb` after every sync as a safety net: TV rows sharing `(show_title, season_number, episode_number, date)` are collapsed to the earliest `pub_ts`. Music/film dedupe stays a manual check.

## Lookup Rules

- Check `media.json` first before doing any web research.
- If the same film already exists in `media.json` with `director` populated, reuse that value.
- If an album year is already known from an existing matching entry, reuse it rather than querying MusicBrainz again.
- Only fall back to web lookup when the field is still missing after checking existing data.
- Keep nullable fields null rather than inventing values.

After editing `media.json` directly (not via the sync script), restart the Jekyll server or `touch _data/media.json` to trigger a rebuild — auto-regeneration does not always pick up manual edits.

## Serializd Diary API

**Endpoint:** `GET https://serializd.onrender.com/api/user/{username}/diary`

**Required headers:**
- `Authorization: Bearer {SERIALIZD_TOKEN}`
- `X-Requested-With: serializd_vercel`

**Params:**
- `page` (int, default 1) — 24 entries per page
- `include_target` — omit for all, or filter by `shows` / `episodes` / `seasons`

**Response shape:** `{ reviews: [...], totalPages: N, totalReviews: null }`

**Entry fields:** `id`, `backdate`, `dateAdded`, `rating` (0 = unrated), `isLog`, `isRewatch`, `episodeNumber`, `episodeName`, `seasonId`, `showId`, `showName`, `showPremiereDate`, `reviewText`, `like`, `tags`

**Season resolution:** Each entry also includes `showSeasons` — an array of `{ id, seasonNumber, name, posterPath }` objects for the show. Match `seasonId` against `showSeasons[].id` to get the actual `seasonNumber`. No external lookup needed.

**Token:** JWT with ~1-year lifetime. The user extracts it from `document.cookie` in the browser console while logged into serializd.com — grab the `tvproject_credentials=...` value and store it as `SERIALIZD_TOKEN` in `.env`. Check the JWT `expiry_time` field if the API returns 401.

## Failure Handling

- If the script reports `Missing LASTFM_API_KEY`, the `.env` file is missing or the key is not set in it.
- If Last.fm or another upstream service returns a transient error (e.g. HTTP 502), retry once before concluding the sync failed.
- Do not overwrite or revert unrelated changes in `_data/media.json` or the sync scripts unless the user explicitly asks.

## Response Pattern

After a sync, report:

1. Which sources ran (Record Club, Last.fm fallback, Letterboxd).
2. Whether `.env` was used (if relevant).
3. Key counters from the script output.
4. A list of genuinely new albums, films, and TV entries added.
5. Any directors resolved manually via web search, with source links.
6. Whether the user provided Serializd diary entries for TV updates.
7. Any nullable lookup fields that remain unresolved.
