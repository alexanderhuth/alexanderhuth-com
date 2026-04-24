#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "json"
require "net/http"
require "optparse"
require "rexml/document"
require "time"
require_relative "musicbrainz"

DEFAULT_RSS_URL = "https://letterboxd.com/alexanderh/rss/"
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
    dry_run: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/sync_letterboxd.rb [options]"
    opts.on("--rss-url URL", "Letterboxd RSS URL (default: #{DEFAULT_RSS_URL})") { |value| options[:rss_url] = value }
    opts.on("--dry-run", "Do not write _data/media.json") { options[:dry_run] = true }
  end.parse!

  options
end

def fetch_feed(rss_url)
  uri = URI(rss_url)
  response = Net::HTTP.get_response(uri)
  abort("Letterboxd request failed: HTTP #{response.code}") unless response.is_a?(Net::HTTPSuccess)

  response.body
end

def text_at(element, path)
  node = element.elements[path]
  node&.text&.strip
end

def normalize_text(value)
  value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
end

def build_existing_director_indexes(entries)
  by_url = {}
  by_title_year = {}

  entries.each do |entry|
    next unless entry["type"] == "film"

    director = entry["director"].to_s.strip
    next if director.empty?

    url = entry["url"].to_s.strip
    by_url[url] ||= director unless url.empty?

    title = entry["title"].to_s.strip
    year = entry["year"]
    next if title.empty? || year.nil?

    by_title_year[[normalize_text(title), year.to_i]] ||= director
  end

  [by_url, by_title_year]
end

def existing_director_for(link:, title:, year:, by_url:, by_title_year:)
  url = link.to_s.strip
  return by_url[url] if !url.empty? && by_url.key?(url)

  return nil if title.to_s.strip.empty? || year.nil?

  by_title_year[[normalize_text(title), year.to_i]]
end

def parse_feed_items(xml, existing_entries:)
  doc = REXML::Document.new(xml)
  items = []
  existing_directors_by_url, existing_directors_by_title_year = build_existing_director_indexes(existing_entries)

  doc.elements.each("rss/channel/item") do |item|
    guid = text_at(item, "guid")
    next unless guid&.include?("letterboxd-watch-")

    watched_date = text_at(item, "letterboxd:watchedDate")
    next unless watched_date

    begin
      date = Date.parse(watched_date)
    rescue ArgumentError
      next
    end

    title = text_at(item, "letterboxd:filmTitle")
    year = text_at(item, "letterboxd:filmYear")
    link = text_at(item, "link")
    pub_date = text_at(item, "pubDate")
    next if title.to_s.empty?

    normalized_year = year.to_s.match?(/^\d{4}$/) ? year.to_i : nil
    director = existing_director_for(
      link: link,
      title: title,
      year: normalized_year,
      by_url: existing_directors_by_url,
      by_title_year: existing_directors_by_title_year
    )

    pub_ts = pub_date ? Time.parse(pub_date).to_i : nil rescue nil

    items << {
      "guid" => guid,
      "source" => "letterboxd",
      "type" => "film",
      "emoji" => "🎬",
      "date" => date.iso8601,
      "date_display" => date_display(date),
      "month" => month_label(date),
      "title" => title,
      "year" => normalized_year,
      "director" => director.to_s.strip.empty? ? nil : director.strip,
      "url" => link,
      "pub_ts" => pub_ts
    }
  end

  items
end

def load_media_data(path)
  return { "entries" => [] } unless File.exist?(path)

  JSON.parse(File.read(path))
end


def film_signature(entry)
  return nil unless entry["type"] == "film"

  title = entry["title"].to_s.strip
  year = entry["year"]
  date = entry["date"].to_s.strip
  return nil if title.empty? || year.nil? || date.empty?

  [date, normalize_text(title), year.to_i]
end

def run
  options = parse_options

  data = load_media_data(MEDIA_PATH)
  existing_entries = data["entries"] || []

  xml = fetch_feed(options[:rss_url])
  all_items = parse_feed_items(xml, existing_entries: existing_entries)
  all_items = all_items.uniq { |item| item["guid"] }

  existing_guids = existing_entries.map { |entry| entry["guid"] }.compact.to_h { |guid| [guid, true] }
  existing_film_signatures = existing_entries.filter_map { |entry| film_signature(entry) }.to_h { |sig| [sig, true] }
  added_items = all_items.reject do |item|
    existing_guids[item["guid"]] || existing_film_signatures[film_signature(item)]
  end
  merged = existing_entries + added_items

  puts "Letterboxd watch items in feed: #{all_items.length}"
  puts "Added Letterboxd entries: #{added_items.length}"
  puts "Appending only new entries in #{MEDIA_PATH}"

  unless options[:dry_run]
    data["entries"] = merged
    File.write(MEDIA_PATH, JSON.pretty_generate(data) + "\n")
    puts "Wrote #{merged.length} total entries."
  end
end

run if __FILE__ == $PROGRAM_NAME
