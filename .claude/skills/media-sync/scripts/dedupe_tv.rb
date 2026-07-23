#!/usr/bin/env ruby
# frozen_string_literal: true

# Drop TV entries that share (show_title, season_number, episode_number, date)
# with another TV entry. When collisions exist, keep the earliest pub_ts — that
# is the first-added row and the one already sorted into place. All fields
# except pub_ts are expected to match; if a field diverges, that's a data bug
# worth surfacing rather than silently collapsing.

require "json"
require "optparse"

MEDIA_PATH = "_data/media.json"

options = { dry_run: false }
OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/dedupe_tv.rb [--dry-run]"
  opts.on("--dry-run", "Report duplicates without writing") { options[:dry_run] = true }
end.parse!

data = JSON.parse(File.read(MEDIA_PATH, encoding: "UTF-8"))
entries = data.fetch("entries")

tv_key = ->(e) { [e["show_title"], e["season_number"], e["episode_number"], e["date"]] }

seen = {}
dropped = []
kept = []
entries.each_with_index do |entry, idx|
  if entry["type"] != "tv"
    kept << entry
    next
  end

  key = tv_key.call(entry)
  prior = seen[key]
  if prior.nil?
    seen[key] = { idx: kept.size, pub_ts: entry["pub_ts"] }
    kept << entry
    next
  end

  # Collision: keep the earlier pub_ts, drop the later one.
  incoming_pub_ts = entry["pub_ts"].to_i
  if incoming_pub_ts < prior[:pub_ts].to_i
    dropped << kept[prior[:idx]]
    kept[prior[:idx]] = entry
    seen[key] = { idx: prior[:idx], pub_ts: entry["pub_ts"] }
  else
    dropped << entry
  end
end

if dropped.empty?
  puts "dedupe_tv: no TV duplicates."
  exit 0
end

puts "dedupe_tv: dropping #{dropped.size} duplicate TV #{dropped.size == 1 ? "entry" : "entries"}:"
dropped.each do |e|
  label = format(
    "  %s S%02dE%02d (%s) pub_ts=%d",
    e["show_title"], e["season_number"].to_i, e["episode_number"].to_i, e["date"], e["pub_ts"].to_i
  )
  puts label
end

if options[:dry_run]
  puts "dedupe_tv: --dry-run, not writing."
  exit 0
end

data["entries"] = kept
File.write(MEDIA_PATH, JSON.pretty_generate(data) + "\n")
puts "dedupe_tv: wrote #{MEDIA_PATH} (#{kept.size} entries)."
