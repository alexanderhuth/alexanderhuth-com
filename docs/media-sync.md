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
ruby scripts/sync_media.rb
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

Shared fields on every entry: `type`, `emoji`, `date`, `date_display`, `month`

| Type | Additional fields |
|---|---|
| Film | `title`, `year`, `director`, `url` (Letterboxd) |
| Music (Record Club) | `album`, `artist`, `year`, `url` (Record Club release page) |
| Music (Last.fm) | `album`, `artist`, `year`, `set_track_count`, `set_start_uts`, `set_end_uts` |
| TV | `show_title`, `season_number`, `episode_number`, `episode_title` |

## Entry Ordering

Within a single `date`: TV rows on top, film rows in the middle, album rows at the bottom.
For TV entries on the same date: newest episode above, oldest below.

## Deduplication

- Do not create duplicates for existing entries.
- Reuse existing metadata from `media.json` before looking anything up.
- Keep nullable fields `null` rather than inventing values.
- Record Club entries use the diary entry URL as GUID (unique per listen, `/2` suffix for repeats).
- Last.fm entries use `lastfm-album-set-{album_key}|{start_uts}|{end_uts}` as GUID.

## Feeds

| Feed | URL | Contents |
|---|---|---|
| Full | `/feed.xml` | Posts + recent media + photos |
| Posts only | `/posts.xml` | Blog posts only |
| Photos only | `/photos.xml` | Photo entries |
