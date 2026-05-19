# Media Sync

Import new media activity into `_data/media.json` whenever you feel like it.

## Sources

| Type | Source | Method |
|---|---|---|
| Music | Record Club | Automated via `sync_recordclub.rb` (primary) |
| Music | Last.fm | Automated via `sync_lastfm.rb` (fallback) |
| Films | Letterboxd | Automated via `sync_letterboxd.rb` |
| TV | Serializd | Manual entry |

## Running a Sync

```bash
ruby .claude/skills/media-sync/scripts/sync_media.rb
# Options:
#   --dry-run   preview changes without writing
```

Record Club and Letterboxd import everything new in their RSS feeds. Last.fm only
runs as a fallback when Record Club returns no new entries, fetching from the
timestamp of the most recent existing Last.fm entry (or 90 days back if none exist).

## Workflow

1. Check [Serializd diary](https://www.serializd.com/user/alexanderh/diary) for new TV entries.
2. Run the sync script.
3. Review the diff; resolve any missing directors via web search.
4. Add TV entries manually.

## Output Schema

Shared fields on every entry: `type`, `emoji`, `date`, `date_display`, `month`, `pub_ts`

| Type | Additional fields |
|---|---|
| Film | `title`, `year`, `director`, `url` (Letterboxd) |
| Music (Record Club) | `album`, `artist`, `year`, `url` (Record Club release page) |
| Music (Last.fm) | `album`, `artist`, `year`, `set_track_count`, `set_start_uts`, `set_end_uts` |
| TV | `show_title`, `season_number`, `episode_number`, `episode_title` |

## Entry Ordering

Entries are sorted at build time by `date` descending (primary), then `pub_ts` descending within each date. JSON order is not meaningful.

- **Films**: `pub_ts` comes from the Letterboxd RSS `pubDate` (or review GUID as fallback).
- **Music (Record Club)**: `pub_ts` comes from the RSS `pubDate`.
- **Music (Last.fm)**: `pub_ts` is copied from `set_start_uts`.
- **TV**: synthetic `pub_ts` assigned manually, set higher than the highest non-TV `pub_ts` on the same date so TV appears above albums and films for that day.

## Deduplication

- Do not create duplicates for existing entries.
- Reuse existing metadata from `media.json` before looking anything up.
- Keep nullable fields `null` rather than inventing values.
- Record Club entries use the diary entry URL as GUID (unique per listen, `/2` suffix for repeats).
- Last.fm entries use `lastfm-album-set-{album_key}|{start_uts}|{end_uts}` as GUID.
