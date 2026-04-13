---
name: media-sync
description: Run the media sync for this Jekyll site when the user wants to import new listening or watching activity into `_data/media.json`, or troubleshoot the Ruby sync workflow in `scripts/sync_media.rb`.
---

# Media Sync

Use this skill to import new media activity. It runs `scripts/sync_media.rb`, which updates `_data/media.json` from Record Club (primary), Last.fm (fallback), and Letterboxd sources.

## When To Use It

- The user wants to sync new media activity.
- The user wants to debug why the media sync failed.
- The user wants to understand which files, env vars, or scripts are involved.

## Output Schema

The canonical media data is structured, not display-string based.

- Films: `title`, `year`, `director`
- Music: `album`, `artist`, `year`
- TV: `show_title`, `season_number`, `episode_number`, `episode_title`
- Shared fields: `type`, `emoji`, `date`, `date_display`, `month`
- Optional sync/provenance fields: `guid`, `source`, `url`, `set_track_count`, `set_start_uts`, `set_end_uts`

Do not treat `lead` or `meta` as canonical fields.

## Inputs And Dependencies

- Run from the repository root.
- Expected env file: `.env`
- Required env var: `LASTFM_API_KEY` (only needed when Last.fm fallback fires)
- Primary entrypoint: `scripts/sync_media.rb`
- Secondary scripts:
  - `scripts/sync_recordclub.rb` — Record Club RSS (primary music source)
  - `scripts/sync_lastfm.rb` — Last.fm API (fallback when Record Club returns no new entries)
  - `scripts/sync_letterboxd.rb` — Letterboxd RSS (films)

## Workflow

1. Inspect the current worktree before running. `_data/media.json` is expected to change; note any unrelated edits already present.

2. Read the existing recent entries before syncing. Treat `_data/media.json` as the first source of truth for known years, directors, and previously imported items.
   - The JSON shape is `{ "entries": [...] }`.
   - The `month` field is a label such as `"April 2026"`, not `"2026-04"`.

3. **Always ask** whether there are any new TV entries on [Serializd diary](https://www.serializd.com/user/alexanderh/diary) — do this every time, even if the user didn't mention it.
   - If the page is not accessible from the current environment, ask the user to paste the new entries.
   - Treat the user's pasted list as source data for manual TV updates to `_data/media.json`.

4. Run the sync from the repo root:

```bash
ruby scripts/sync_media.rb
ruby scripts/sync_media.rb --dry-run
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

Within a single `date`, entries must be ordered by type: **TV rows on top, film rows in the middle, album rows at the bottom.**

For TV entries that share the same `date`, preserve chronological episode order: **oldest episode below, newest above.**

When adding new entries, insert them so that both rules hold across the whole file (which is sorted newest-first by date overall).

## Deduplication Rules

- Do not create duplicates for entries already present in `media.json`.
- Only add a new row when the media was actually consumed as a distinct event.
- For music, repeat listens of the same album are valid when the underlying listen window is different.
- For films and TV, use the existing item identity and date data to avoid duplicate rows for the same watch.

## Lookup Rules

- Check `media.json` first before doing any web research.
- If the same film already exists in `media.json` with `director` populated, reuse that value.
- If an album year is already known from an existing matching entry, reuse it rather than querying MusicBrainz again.
- Only fall back to web lookup when the field is still missing after checking existing data.
- Keep nullable fields null rather than inventing values.

## Within-Date Ordering

Entries within a date are sorted by: **type** (TV → film → music), then **sub-timestamp descending** (`set_start_uts` for Last.fm, `pub_ts` for RC/Letterboxd).

For RC entries sharing the same listen date, `pub_ts` (from RSS `pubDate`) is the tiebreaker: older pubDate = listened earlier = shown lower on page (page is newest-first, so highest pub_ts appears at top).

After editing `media.json` directly (not via the sync script), restart the Jekyll server or `touch _data/media.json` to trigger a rebuild — auto-regeneration does not always pick up manual edits.

## Failure Handling

- If the script reports `Missing LASTFM_API_KEY`, load `.env` or export the variable and rerun.
- If Last.fm or another upstream service returns a transient error (e.g. HTTP 502), retry once before concluding the sync failed.
- If the sync rewrites ordering beyond the genuinely new rows, call that out rather than silently accepting it.
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
