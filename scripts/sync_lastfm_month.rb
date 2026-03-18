#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "optparse"
require "time"
require "date"
require "uri"

DEFAULT_USER = "lxndrrr"
DEFAULT_TIMEZONE = "Europe/Berlin"
DEFAULT_LIMIT = 200
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

def year_from_date(value)
  match = value.to_s.match(/\A(\d{4})/)
  match && match[1].to_i
end

def musicbrainz_get(path, params = {})
  @musicbrainz_last_request_at ||= Time.at(0)
  elapsed = Time.now - @musicbrainz_last_request_at
  sleep(1.1 - elapsed) if elapsed < 1.1

  uri = URI("#{MUSICBRAINZ_API}/#{path}")
  uri.query = URI.encode_www_form(params.merge(fmt: "json"))
  request = Net::HTTP::Get.new(uri)
  request["User-Agent"] = USER_AGENT

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end
  @musicbrainz_last_request_at = Time.now

  return nil unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
rescue StandardError
  nil
end

def lookup_album_year(album_name, artist_name, album_mbid, cache)
  cache_key = [album_mbid.to_s.strip.downcase, normalize_text(album_name), normalize_text(artist_name)]
  return cache[cache_key] if cache.key?(cache_key)

  year = lookup_album_year_from_mbid(album_mbid)
  year ||= lookup_album_year_from_search(album_name, artist_name)
  cache[cache_key] = year
end

def lookup_album_year_from_mbid(album_mbid)
  mbid = album_mbid.to_s.strip
  return nil if mbid.empty?

  release_group = musicbrainz_get("release-group/#{mbid}")
  year = year_from_date(release_group && release_group["first-release-date"])
  return year if year

  release = musicbrainz_get("release/#{mbid}", inc: "release-groups")
  year = year_from_date(release && release["date"])
  return year if year

  release_group = release && release["release-group"]
  year_from_date(release_group && release_group["first-release-date"])
end

def lookup_album_year_from_search(album_name, artist_name)
  return nil if album_name.to_s.strip.empty? || artist_name.to_s.strip.empty?

  query = %(releasegroup:"#{album_name}" AND artist:"#{artist_name}")
  payload = musicbrainz_get("release-group", query: query, limit: 5)
  results = payload && payload["release-groups"]
  return nil unless results.is_a?(Array)

  expected_album = normalize_text(album_name)
  expected_artist = normalize_text(artist_name)

  match = results.find do |result|
    title_match = normalize_text(result["title"]) == expected_album
    artist_credit = Array(result["artist-credit"]).filter_map { |credit| credit["name"] || credit.dig("artist", "name") }.join(" ")
    artist_match = normalize_text(artist_credit).include?(expected_artist)
    title_match && artist_match
  end

  match ||= results.first
  year_from_date(match && match["first-release-date"])
end

def build_existing_album_year_index(entries)
  entries.each_with_object({}) do |entry, index|
    next unless entry["type"] == "music"

    album = entry["album"].to_s.strip
    artist = entry["artist"].to_s.strip
    year = entry["year"]
    next if album.empty? || artist.empty? || year.nil?

    index[[normalize_text(album), normalize_text(artist)]] ||= year
  end
end

def build_entries(album_sets:, target_month_start:, timezone:, existing_album_years:)
  month_end = (target_month_start >> 1) - 1
  album_year_cache = existing_album_years.dup

  album_sets.filter_map do |set|
    first_uts = set[:tracks].first[:uts]
    last_uts = set[:tracks].last[:uts]
    start_local = local_time_in_timezone(first_uts, timezone)
    listen_date = start_local.to_date

    # If a replay crosses midnight, keep the earlier day (start of the set).
    next if listen_date < target_month_start || listen_date > month_end

    album_name = set[:tracks].first[:album]
    artist_name = dominant_artist(set[:tracks])
    album_key = [normalize_text(album_name), normalize_text(artist_name)]
    album_year = album_year_cache[album_key]
    album_year ||= lookup_album_year(album_name, artist_name, set[:tracks].first[:album_mbid], album_year_cache)
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

def run
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

  data = load_media_data(MEDIA_PATH)
  existing_entries = data["entries"] || []
  existing_album_years = build_existing_album_year_index(existing_entries)
  existing_guids = existing_entries.map { |entry| entry["guid"] }.compact.to_h { |guid| [guid, true] }
  new_entries = build_entries(
    album_sets: album_sets,
    target_month_start: month_start,
    timezone: options[:timezone],
    existing_album_years: existing_album_years
  )
  added_entries = new_entries.reject { |entry| existing_guids[entry["guid"]] }
  merged = sort_entries(existing_entries + added_entries)

  puts "Month: #{month_start.strftime('%Y-%m')}"
  puts "Fetched tracks: #{tracks.length} (from #{raw_tracks.length} raw API items)"
  puts "Detected album sets: #{album_sets.length}"
  puts "New month entries: #{new_entries.length}"
  puts "Added Last.fm entries: #{added_entries.length}"
  puts "Appending only new entries in #{MEDIA_PATH}"

  unless options[:dry_run]
    data["entries"] = merged
    File.write(MEDIA_PATH, JSON.pretty_generate(data) + "\n")
    puts "Wrote #{merged.length} total entries."
  end
end

run if __FILE__ == $PROGRAM_NAME
