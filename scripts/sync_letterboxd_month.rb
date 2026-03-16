#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "json"
require "net/http"
require "optparse"
require "rexml/document"

DEFAULT_RSS_URL = "https://letterboxd.com/alexanderh/rss/"

def month_label(date)
  date.strftime("%B %Y")
end

def date_display(date)
  date.strftime("%b %-d")
end

def parse_options
  options = {
    rss_url: DEFAULT_RSS_URL,
    month: nil,
    dry_run: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/sync_letterboxd_month.rb [options]"
    opts.on("--month YYYY-MM", "Target month (default: previous month)") do |value|
      options[:month] = value
    end
    opts.on("--rss-url URL", "Letterboxd RSS URL (default: #{DEFAULT_RSS_URL})") do |value|
      options[:rss_url] = value
    end
    opts.on("--dry-run", "Do not write _data/media.json") do
      options[:dry_run] = true
    end
  end.parse!

  options
end

def target_month(options)
  if options[:month]
    Date.strptime(options[:month], "%Y-%m")
  else
    today = Date.today
    Date.new(today.year, today.month, 1) << 1
  end
rescue ArgumentError
  abort("Invalid --month format. Use YYYY-MM.")
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

def parse_feed_items(xml)
  doc = REXML::Document.new(xml)
  items = []

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
    next if title.to_s.empty?

    lead = if year.to_s.match?(/^\d{4}$/)
      "**#{title}** (#{year})"
    else
      "**#{title}**"
    end

    items << {
      "guid" => guid,
      "source" => "letterboxd",
      "type" => "film",
      "emoji" => "🎬",
      "date" => date.iso8601,
      "date_display" => date_display(date),
      "month" => month_label(date),
      "lead" => lead,
      "meta" => nil,
      "url" => link
    }
  end

  items
end

def load_media_data(path)
  return { "entries" => [] } unless File.exist?(path)

  JSON.parse(File.read(path))
end

def sort_entries(entries)
  entries.sort_by do |entry|
    t = entry["set_start_uts"] || entry["date"]
    [entry["date"].to_s, t.to_s]
  end.reverse
end

options = parse_options
month = target_month(options)
month_prefix = month.strftime("%Y-%m")

xml = fetch_feed(options[:rss_url])
all_items = parse_feed_items(xml)
month_items = all_items.select { |item| item["date"].start_with?(month_prefix) }
month_items = month_items.uniq { |item| item["guid"] }

path = "_data/media.json"
data = load_media_data(path)
existing_entries = data["entries"] || []
existing_guids = existing_entries.map { |entry| entry["guid"] }.compact.to_h { |guid| [guid, true] }
added_items = month_items.reject { |item| existing_guids[item["guid"]] }
merged = sort_entries(existing_entries + added_items)

puts "Month: #{month_prefix}"
puts "Letterboxd watch items in feed: #{all_items.length}"
puts "Month watch entries selected: #{month_items.length}"
puts "Added Letterboxd entries: #{added_items.length}"
puts "Appending only new entries in #{path}"

unless options[:dry_run]
  data["entries"] = merged
  File.write(path, JSON.pretty_generate(data) + "\n")
  puts "Wrote #{merged.length} total entries."
end
