# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

MUSICBRAINZ_API = "https://musicbrainz.org/ws/2"
USER_AGENT = "alexanderhuth-com-media-sync/1.0 (https://alexanderhuth.com)"

def normalize_text(value)
  value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
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
    artist_credit = Array(result["artist-credit"])
      .filter_map { |credit| credit["name"] || credit.dig("artist", "name") }
      .join(" ")
    artist_match = normalize_text(artist_credit).include?(expected_artist)
    title_match && artist_match
  end

  match ||= results.first
  year_from_date(match && match["first-release-date"])
end

def lookup_album_year(album_name, artist_name, cache, album_mbid: nil)
  cache_key = [album_mbid.to_s.strip.downcase, normalize_text(album_name), normalize_text(artist_name)]
  return cache[cache_key] if cache.key?(cache_key)

  search_year = lookup_album_year_from_search(album_name, artist_name)
  mbid_year = lookup_album_year_from_mbid(album_mbid)
  year = [search_year, mbid_year].compact.min
  cache[cache_key] = year
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
