#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "optparse"
require "time"
require "date"

DEFAULT_USER = "lxndrrr"
DEFAULT_TIMEZONE = "Europe/Berlin"
DEFAULT_LIMIT = 200

def month_label(date)
  date.strftime("%B %Y")
end

def date_display(time)
  time.strftime("%b %-d")
end

def parse_options
  options = {
    user: DEFAULT_USER,
    timezone: DEFAULT_TIMEZONE,
    limit: DEFAULT_LIMIT,
    dry_run: false,
    month: nil
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/sync_lastfm_month.rb [options]"
    opts.on("--month YYYY-MM", "Target month (default: previous month)") do |value|
      options[:month] = value
    end
    opts.on("--user USER", "Last.fm user (default: #{DEFAULT_USER})") do |value|
      options[:user] = value
    end
    opts.on("--timezone TZ", "Timezone for listen day (default: #{DEFAULT_TIMEZONE})") do |value|
      options[:timezone] = value
    end
    opts.on("--limit N", Integer, "Page size for Last.fm API (default: #{DEFAULT_LIMIT})") do |value|
      options[:limit] = value
    end
    opts.on("--dry-run", "Do not write _data/media.json") do
      options[:dry_run] = true
    end
  end.parse!

  options
end

def target_month(options)
  if options[:month]
    Time.strptime(options[:month], "%Y-%m").to_date
  else
    today = Time.now.getlocal.strftime("%Y-%m-%d")
    date = Date.parse(today)
    Date.new(date.year, date.month, 1) << 1
  end
rescue ArgumentError
  abort("Invalid --month format. Use YYYY-MM.")
end

def fetch_recent_tracks(user:, api_key:, limit:, from_ts:, to_ts:)
  page = 1
  all_tracks = []

  loop do
    uri = URI("https://ws.audioscrobbler.com/2.0/")
    uri.query = URI.encode_www_form(
      method: "user.getRecentTracks",
      user: user,
      api_key: api_key,
      format: "json",
      limit: limit,
      page: page,
      from: from_ts,
      to: to_ts
    )

    response = Net::HTTP.get_response(uri)
    abort("Last.fm request failed: HTTP #{response.code}") unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body)
    recenttracks = payload["recenttracks"] || {}
    attr = recenttracks["@attr"] || {}
    page_tracks = recenttracks["track"] || []
    page_tracks = [page_tracks] if page_tracks.is_a?(Hash)

    all_tracks.concat(page_tracks)

    total_pages = attr["totalPages"].to_i
    break if total_pages <= 1 || page >= total_pages || page_tracks.empty?

    page += 1
  end

  all_tracks
end

def normalize_tracks(raw_tracks)
  raw_tracks.filter_map do |track|
    date = track["date"]
    next unless date && date["uts"]

    uts = date["uts"].to_i
    album = track.dig("album", "#text").to_s.strip
    album_mbid = track.dig("album", "mbid").to_s.strip
    track_mbid = track["mbid"].to_s.strip
    artist = track.dig("artist", "#text").to_s.strip
    name = track["name"].to_s.strip
    next if album.empty? || artist.empty? || name.empty?

    {
      uts: uts,
      album: album,
      album_mbid: album_mbid,
      artist: artist,
      track: name,
      track_mbid: track_mbid
    }
  end.sort_by { |t| t[:uts] }
end

def canonical_artist_name(name)
  artist = name.to_s.dup
  artist = artist.sub(/\s+\[feat\..*$/i, "")
  artist = artist.sub(/\s+\(feat\..*$/i, "")
  artist = artist.sub(/\s+feat\..*$/i, "")
  artist.strip
end

def dominant_artist(tracks)
  normalized = tracks.map { |t| canonical_artist_name(t[:artist]) }.reject(&:empty?)
  return tracks.first[:artist] if normalized.empty?

  frequencies = normalized.each_with_object(Hash.new(0)) { |artist, counts| counts[artist] += 1 }
  frequencies.max_by { |artist, count| [count, -artist.length] }.first
end

def track_identity(track)
  mbid = track[:track_mbid].to_s.strip
  return "mbid:#{mbid.downcase}" unless mbid.empty?

  "name:#{track[:track].downcase}"
end

def split_replays_within_album_set(album_set)
  tracks = album_set[:tracks]
  return [album_set] if tracks.length <= 1

  album_song_count = tracks.map { |t| track_identity(t) }.uniq.length
  return [album_set] if album_song_count <= 1

  split_sets = []
  current_tracks = []
  current_seen = {}

  tracks.each_with_index do |track, index|
    identity = track_identity(track)

    if index.positive? && current_seen.length >= album_song_count && current_seen[identity]
      split_sets << { album_key: album_set[:album_key], tracks: current_tracks }
      current_tracks = []
      current_seen = {}
    end

    current_tracks << track
    current_seen[identity] = true
  end

  split_sets << { album_key: album_set[:album_key], tracks: current_tracks } unless current_tracks.empty?
  split_sets
end

def group_album_sets(tracks)
  sets = []
  current = nil

  tracks.each do |track|
    album_key = if !track[:album_mbid].to_s.empty?
      ["mbid", track[:album_mbid].downcase]
    else
      ["name", track[:album].downcase]
    end
    if current && current[:album_key] == album_key
      current[:tracks] << track
    else
      sets << current if current
      current = { album_key: album_key, tracks: [track] }
    end
  end
  sets << current if current
  sets.flat_map { |set| split_replays_within_album_set(set) }
end

def local_time_in_timezone(uts, timezone)
  old_tz = ENV["TZ"]
  ENV["TZ"] = timezone
  Time.at(uts).localtime
ensure
  ENV["TZ"] = old_tz
end

def build_entries(album_sets:, target_month_start:, timezone:)
  month_end = (target_month_start >> 1) - 1

  album_sets.filter_map do |set|
    first_uts = set[:tracks].first[:uts]
    last_uts = set[:tracks].last[:uts]
    start_local = local_time_in_timezone(first_uts, timezone)
    listen_date = start_local.to_date

    # If a replay crosses midnight, keep the earlier day (start of the set).
    next if listen_date < target_month_start || listen_date > month_end

    album_name = set[:tracks].first[:album]
    artist_name = dominant_artist(set[:tracks])
    {
      "guid" => "lastfm-album-set-#{set[:album_key].join('|')}|#{first_uts}|#{last_uts}",
      "source" => "lastfm",
      "type" => "music",
      "emoji" => "💿",
      "date" => listen_date.iso8601,
      "date_display" => date_display(start_local),
      "month" => month_label(listen_date),
      "lead" => "**#{album_name}**",
      "meta" => artist_name,
      "set_track_count" => set[:tracks].length,
      "set_start_uts" => first_uts,
      "set_end_uts" => last_uts
    }
  end
end

def load_media_data(path)
  if File.exist?(path)
    JSON.parse(File.read(path))
  else
    { "entries" => [] }
  end
end

def sort_entries(entries)
  entries.sort_by do |entry|
    uts = entry["set_start_uts"]
    if uts
      [0, uts.to_i]
    else
      [1, Time.parse("#{entry['date']} 00:00:00 UTC").to_i]
    end
  rescue ArgumentError
    [2, 0]
  end.reverse
end

options = parse_options
api_key = ENV["LASTFM_API_KEY"]
abort("Missing LASTFM_API_KEY in environment.") if api_key.to_s.strip.empty?
abort("Limit must be between 1 and 200.") if options[:limit].to_i < 1 || options[:limit].to_i > 200

month = target_month(options)
month_start = Date.new(month.year, month.month, 1)
month_end = (month_start >> 1) - 1

# Include one day on each side so sets crossing month boundaries are resolved correctly.
from_ts = Time.parse("#{(month_start - 1).iso8601} 00:00:00 UTC").to_i
to_ts = Time.parse("#{(month_end + 1).iso8601} 23:59:59 UTC").to_i

raw_tracks = fetch_recent_tracks(
  user: options[:user],
  api_key: api_key,
  limit: options[:limit],
  from_ts: from_ts,
  to_ts: to_ts
)
tracks = normalize_tracks(raw_tracks)
album_sets = group_album_sets(tracks)
new_entries = build_entries(album_sets: album_sets, target_month_start: month_start, timezone: options[:timezone])

path = "_data/media.json"
data = load_media_data(path)
existing_entries = data["entries"] || []
existing_guids = existing_entries.map { |entry| entry["guid"] }.compact.to_h { |guid| [guid, true] }
added_entries = new_entries.reject { |entry| existing_guids[entry["guid"]] }
merged = sort_entries(existing_entries + added_entries)

puts "Month: #{month_start.strftime('%Y-%m')}"
puts "Fetched tracks: #{tracks.length} (from #{raw_tracks.length} raw API items)"
puts "Detected album sets: #{album_sets.length}"
puts "New month entries: #{new_entries.length}"
puts "Added Last.fm entries: #{added_entries.length}"
puts "Appending only new entries in #{path}"

unless options[:dry_run]
  data["entries"] = merged
  File.write(path, JSON.pretty_generate(data) + "\n")
  puts "Wrote #{merged.length} total entries."
end
