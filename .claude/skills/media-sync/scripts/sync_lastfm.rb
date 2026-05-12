#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "optparse"
require "time"
require "date"
require "uri"
require_relative "musicbrainz"

DEFAULT_USER = "lxndrrr"
DEFAULT_TIMEZONE = "Europe/Berlin"
DEFAULT_LIMIT = 200
DEFAULT_LOOKBACK_DAYS = 90
MEDIA_PATH = "_data/media.json"
MUSICBRAINZ_API = "https://musicbrainz.org/ws/2"
USER_AGENT = "alexanderhuth-com-media-sync/1.0 (https://alexanderhuth.com)"

def month_label(date)
  date.strftime("%B %Y")
end

def date_display(time)
  time.strftime("%b %-d")
end

def normalize_text(value)
  value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
end

def parse_options
  options = {
    user: DEFAULT_USER,
    timezone: DEFAULT_TIMEZONE,
    limit: DEFAULT_LIMIT,
    dry_run: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/sync_lastfm.rb [options]"
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

# Returns [from_ts, to_ts] based on the most recent Last.fm entry already in media.json.
# Falls back to DEFAULT_LOOKBACK_DAYS if no prior Last.fm entries exist.
def fetch_window(existing_entries)
  lastfm_entries = existing_entries.select { |e| e["source"] == "lastfm" && e["set_end_uts"] }
  if lastfm_entries.any?
    from_ts = lastfm_entries.map { |e| e["set_end_uts"].to_i }.max + 1
  else
    from_ts = Time.now.to_i - (DEFAULT_LOOKBACK_DAYS * 24 * 3600)
  end
  [from_ts, Time.now.to_i]
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


def build_entries(album_sets:, timezone:, existing_album_years:)
  album_year_cache = existing_album_years.dup

  album_sets.map do |set|
    first_uts = set[:tracks].first[:uts]
    last_uts = set[:tracks].last[:uts]
    start_local = local_time_in_timezone(first_uts, timezone)
    listen_date = start_local.to_date

    album_name = set[:tracks].first[:album]
    artist_name = dominant_artist(set[:tracks])
    album_key = [normalize_text(album_name), normalize_text(artist_name)]
    album_year = album_year_cache[album_key]
    album_year ||= lookup_album_year(album_name, artist_name, album_year_cache, album_mbid: set[:tracks].first[:album_mbid])
    album_year_cache[album_key] ||= album_year unless album_year.nil?

    {
      "guid" => "lastfm-album-set-#{set[:album_key].join('|')}|#{first_uts}|#{last_uts}",
      "source" => "lastfm",
      "type" => "music",
      "emoji" => "💿",
      "date" => listen_date.iso8601,
      "date_display" => date_display(start_local),
      "month" => month_label(listen_date),
      "album" => album_name,
      "artist" => artist_name,
      "year" => album_year,
      "pub_ts" => first_uts,
      "set_track_count" => set[:tracks].length,
      "set_start_uts" => first_uts,
      "set_end_uts" => last_uts
    }
  end
end

def load_media_data(path)
  if File.exist?(path)
    JSON.parse(File.read(path, encoding: "UTF-8"))
  else
    { "entries" => [] }
  end
end


def load_dotenv(path)
  return unless File.exist?(path)

  File.foreach(path) do |line|
    next if line.strip.empty? || line.lstrip.start_with?("#")

    key, value = line.split("=", 2)
    next unless key && value

    key = key.strip
    next if key.empty?

    value = value.strip
    if (value.start_with?('"') && value.end_with?('"')) ||
       (value.start_with?("'") && value.end_with?("'"))
      value = value[1..-2]
    end

    ENV[key] ||= value
  end
end

def run
  options = parse_options
  load_dotenv(File.expand_path(".env"))
  api_key = ENV["LASTFM_API_KEY"]
  abort("Missing LASTFM_API_KEY in environment.") if api_key.to_s.strip.empty?
  abort("Limit must be between 1 and 200.") if options[:limit].to_i < 1 || options[:limit].to_i > 200

  data = load_media_data(MEDIA_PATH)
  existing_entries = data["entries"] || []

  from_ts, to_ts = fetch_window(existing_entries)
  from_label = Time.at(from_ts).strftime("%Y-%m-%d")
  to_label = Time.at(to_ts).strftime("%Y-%m-%d")
  puts "Fetching Last.fm scrobbles from #{from_label} to #{to_label}"

  raw_tracks = fetch_recent_tracks(
    user: options[:user],
    api_key: api_key,
    limit: options[:limit],
    from_ts: from_ts,
    to_ts: to_ts
  )
  tracks = normalize_tracks(raw_tracks)
  album_sets = group_album_sets(tracks)

  existing_album_years = build_existing_album_year_index(existing_entries)
  existing_guids = existing_entries.map { |entry| entry["guid"] }.compact.to_h { |guid| [guid, true] }
  new_entries = build_entries(
    album_sets: album_sets,
    timezone: options[:timezone],
    existing_album_years: existing_album_years
  )
  added_entries = new_entries.reject { |entry| existing_guids[entry["guid"]] }
  merged = existing_entries + added_entries

  puts "Fetched tracks: #{tracks.length} (from #{raw_tracks.length} raw API items)"
  puts "Detected album sets: #{album_sets.length}"
  puts "Added Last.fm entries: #{added_entries.length}"
  puts "Appending only new entries in #{MEDIA_PATH}"

  unless options[:dry_run]
    data["entries"] = merged
    File.write(MEDIA_PATH, JSON.pretty_generate(data) + "\n")
    puts "Wrote #{merged.length} total entries."
  end
end

run if __FILE__ == $PROGRAM_NAME
