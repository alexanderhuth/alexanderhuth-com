#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "json"
require "net/http"
require "optparse"
require "rexml/document"
require "time"
require "uri"
require_relative "musicbrainz"

DEFAULT_RSS_URL = "https://record.club/alexanderh/diary/rss"
DEFAULT_TIMEZONE = "Europe/Berlin"
MEDIA_PATH = "_data/media.json"

def month_label(date)
  date.strftime("%B %Y")
end

def date_display(date)
  date.strftime("%b %-d")
end

def parse_options
  options = {
    rss_url: DEFAULT_RSS_URL,
    timezone: DEFAULT_TIMEZONE,
    dry_run: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/sync_recordclub.rb [options]"
    opts.on("--rss-url URL", "Record Club RSS URL (default: #{DEFAULT_RSS_URL})") { |v| options[:rss_url] = v }
    opts.on("--timezone TZ", "Timezone for listen day (default: #{DEFAULT_TIMEZONE})") { |v| options[:timezone] = v }
    opts.on("--dry-run", "Do not write _data/media.json") { options[:dry_run] = true }
  end.parse!

  options
end

def fetch_feed(rss_url)
  uri = URI(rss_url)
  response = Net::HTTP.get_response(uri)
  abort("Record Club request failed: HTTP #{response.code}") unless response.is_a?(Net::HTTPSuccess)

  response.body
end

def text_at(element, path)
  node = element.elements[path]
  node&.text&.strip
end

# Parses "'Album Title' by Artist Name" with optional ↻ prefix and ★ rating suffix.
# Uses greedy match so album titles containing apostrophes (e.g. "Waited Up 'Til…") work correctly.
def parse_rc_title(raw_title)
  title = raw_title.to_s.strip
  title = title.sub(/\A↻\s+/, "")
  title = title.sub(/\s+-\s+★+½?\z/, "")
  match = title.match(/\A'(.+)' by (.+)\z/)
  return nil unless match

  { album: match[1].strip, artist: match[2].strip }
end

def parse_listen_date(content_html, timezone)
  match = content_html.to_s.match(/Listened:\s+([A-Za-z]+ \d+, \d{4})/)
  return nil unless match

  old_tz = ENV["TZ"]
  ENV["TZ"] = timezone
  date = Date.parse(match[1])
  ENV["TZ"] = old_tz
  date
rescue ArgumentError
  nil
end

# Strip personal diary suffix (/2, /3, …) to get the canonical release page URL.
def canonical_release_url(url)
  url.to_s.sub(/\/\d+\z/, "")
end


def parse_feed_items(xml, timezone:, existing_entries:)
  doc = REXML::Document.new(xml)
  items = []
  album_year_cache = build_existing_album_year_index(existing_entries)

  doc.elements.each("rss/channel/item") do |item|
    guid = text_at(item, "guid")
    next unless guid

    link = text_at(item, "link")
    raw_title = text_at(item, "title")
    content = text_at(item, "content:encoded")
    pub_date = text_at(item, "pubDate")

    parsed = parse_rc_title(raw_title)
    next unless parsed

    listen_date = parse_listen_date(content, timezone)
    next unless listen_date

    album = parsed[:album]
    artist = parsed[:artist]

    album_year = lookup_album_year(album, artist, album_year_cache)
    pub_ts = pub_date ? Time.parse(pub_date).to_i : nil rescue nil

    items << {
      "guid" => guid,
      "source" => "recordclub",
      "type" => "music",
      "emoji" => "💿",
      "date" => listen_date.iso8601,
      "date_display" => date_display(listen_date),
      "month" => month_label(listen_date),
      "album" => album,
      "artist" => artist,
      "year" => album_year,
      "url" => canonical_release_url(link),
      "pub_ts" => pub_ts
    }
  end

  items
end

def music_signature(entry)
  return nil unless entry["type"] == "music"

  date = entry["date"].to_s.strip
  album = entry["album"].to_s.strip
  artist = entry["artist"].to_s.strip
  return nil if date.empty? || album.empty? || artist.empty?

  [date, normalize_text(album), normalize_text(artist)]
end

def load_media_data(path)
  return { "entries" => [] } unless File.exist?(path)

  JSON.parse(File.read(path, encoding: "UTF-8"))
end


def run
  options = parse_options

  data = load_media_data(MEDIA_PATH)
  existing_entries = data["entries"] || []

  xml = fetch_feed(options[:rss_url])
  new_items = parse_feed_items(
    xml,
    timezone: options[:timezone],
    existing_entries: existing_entries
  )

  existing_guids = existing_entries.map { |e| e["guid"] }.compact.to_h { |g| [g, true] }
  existing_music_signatures = existing_entries.filter_map { |e| music_signature(e) }.to_h { |s| [s, true] }
  added_items = new_items.reject do |item|
    existing_guids[item["guid"]] || existing_music_signatures[music_signature(item)]
  end
  merged = existing_entries + added_items

  puts "Record Club items in feed: #{new_items.length}"
  puts "Added Record Club entries: #{added_items.length}"
  puts "Appending only new entries in #{MEDIA_PATH}"

  unless options[:dry_run]
    data["entries"] = merged
    File.write(MEDIA_PATH, JSON.pretty_generate(data) + "\n")
    puts "Wrote #{merged.length} total entries."
  end

  added_items.length
end

if __FILE__ == $PROGRAM_NAME
  count = run
  # Exit 2 signals "no entries added" so the orchestrator can fall back to Last.fm.
  exit 2 if count == 0
end
