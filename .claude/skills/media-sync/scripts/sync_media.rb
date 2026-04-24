#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "rbconfig"

def parse_options
  options = { dry_run: false }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/sync_media.rb [options]"
    opts.on("--dry-run", "Run syncs without writing _data/media.json") do
      options[:dry_run] = true
    end
  end.parse!

  options
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

    ENV[key] = value
  end
end

def run_script(script_name, dry_run:)
  script_path = File.expand_path(script_name, __dir__)
  cmd = [RbConfig.ruby, script_path]
  cmd << "--dry-run" if dry_run
  system(ENV, *cmd)
  $?.exitstatus
end

def run_sync(script_name, dry_run:)
  exit_code = run_script(script_name, dry_run: dry_run)
  abort("Sync failed: #{File.basename(script_name)}") if exit_code == 1
end

# Runs Record Club as primary music source; falls back to Last.fm if Record Club
# returns no entries (exit 2) — e.g. when the RSS doesn't reach far enough back.
def sync_music(dry_run:)
  puts "Trying Record Club..."
  exit_code = run_script("sync_recordclub.rb", dry_run: dry_run)

  case exit_code
  when 0
    # Record Club had entries — done.
  when 2
    puts "No new Record Club entries, falling back to Last.fm..."
    run_sync("sync_lastfm.rb", dry_run: dry_run)
  else
    abort("Sync failed: sync_recordclub.rb")
  end
end

options = parse_options
load_dotenv(File.expand_path(".env"))

puts "Ruby: #{RbConfig.ruby}"

sync_music(dry_run: options[:dry_run])
run_sync("sync_letterboxd.rb", dry_run: options[:dry_run])
