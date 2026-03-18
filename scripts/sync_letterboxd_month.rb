#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "json"
require "net/http"
require "optparse"
require "rexml/document"
require "uri"

DEFAULT_RSS_URL = "https://letterboxd.com/alexanderh/rss/"
MEDIA_PATH = "_data/media.json"
USER_AGENT = "alexanderhuth-com-media-sync/1.0 (https://alexanderhuth.com)"

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
    opts.on("--month YYYY-MM", "Target month (default: previous month)") { |value| options[:month] = value }
    opts.on("--rss-url URL", "Letterboxd RSS URL (default: #{DEFAULT_RSS_URL})") { |value| options[:rss_url] = value }
    opts.on("--dry-run", "Do not write _data/media.json") { options[:dry_run] = true }
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

def normalize_text(value)
  value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
end

def get_text(uri)
  request = Net::HTTP::Get.new(uri)
  request["User-Agent"] = USER_AGENT

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end
  return nil unless response.is_a?(Net::HTTPSuccess)

  response.body
rescue StandardError
  nil
end

def extract_director_names_from_json_ld(node)
  names = []

  case node
  when Array
    node.each { |item| names.concat(extract_director_names_from_json_ld(item)) }
  when Hash
    directors = node["director"]
    case directors
    when Array
      directors.each do |director|
        next unless director.is_a?(Hash)

        name = director["name"].to_s.strip
        names << name unless name.empty?
      end
    when Hash
      name = directors["name"].to_s.strip
      names << name unless name.empty?
    end

    names.concat(extract_director_names_from_json_ld(node["itemReviewed"])) if node.key?("itemReviewed")
    names.concat(extract_director_names_from_json_ld(node["mainEntity"])) if node.key?("mainEntity")
  end

  names.uniq
end

def fetch_director_from_letterboxd(entry_url, cache)
  return nil if entry_url.to_s.strip.empty?
  return cache[entry_url] if cache.key?(entry_url)

  html = get_text(URI(entry_url))
  return cache[entry_url] = nil unless html

  blocks = html.scan(%r{<script type="application/ld\+json">\s*(.*?)\s*</script>}m).flatten
  director = nil

  blocks.each do |payload|
    begin
      json = JSON.parse(payload)
    rescue JSON::ParserError
      next
    end

    names = extract_director_names_from_json_ld(json)
    next if names.empty?

    director = names.join(", ")
    break
  end

  cache[entry_url] = director
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
  director_cache = {}
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
    next if title.to_s.empty?

    normalized_year = year.to_s.match?(/^\d{4}$/) ? year.to_i : nil
    director = existing_director_for(
      link: link,
      title: title,
      year: normalized_year,
      by_url: existing_directors_by_url,
      by_title_year: existing_directors_by_title_year
    )
    director ||= text_at(item, "letterboxd:filmDirector") || text_at(item, "dc:creator")
    director = fetch_director_from_letterboxd(link, director_cache) if director.to_s.strip.empty?

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
  month = target_month(options)
  month_prefix = month.strftime("%Y-%m")

  data = load_media_data(MEDIA_PATH)
  existing_entries = data["entries"] || []

  xml = fetch_feed(options[:rss_url])
  all_items = parse_feed_items(xml, existing_entries: existing_entries)
  month_items = all_items.select { |item| item["date"].start_with?(month_prefix) }
  month_items = month_items.uniq { |item| item["guid"] }

  existing_guids = existing_entries.map { |entry| entry["guid"] }.compact.to_h { |guid| [guid, true] }
  existing_film_signatures = existing_entries.filter_map { |entry| film_signature(entry) }.to_h { |signature| [signature, true] }
  added_items = month_items.reject do |item|
    existing_guids[item["guid"]] || existing_film_signatures[film_signature(item)]
  end
  merged = sort_entries(existing_entries + added_items)

  puts "Month: #{month_prefix}"
  puts "Letterboxd watch items in feed: #{all_items.length}"
  puts "Month watch entries selected: #{month_items.length}"
  puts "Added Letterboxd entries: #{added_items.length}"
  puts "Appending only new entries in #{MEDIA_PATH}"

  unless options[:dry_run]
    data["entries"] = merged
    File.write(MEDIA_PATH, JSON.pretty_generate(data) + "\n")
    puts "Wrote #{merged.length} total entries."
  end
end

run if __FILE__ == $PROGRAM_NAME
