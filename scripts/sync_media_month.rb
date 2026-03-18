#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "optparse"
require "rbconfig"

DEFAULT_MONTH = Date.today.strftime("%Y-%m")

def parse_options
  options = {
    month: DEFAULT_MONTH,
    dry_run: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/sync_media_month.rb [options]"
    opts.on("--month YYYY-MM", "Target month (default: current month)") do |value|
      options[:month] = value
    end
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

def run_sync(script_name, month:, dry_run:)
  script_path = File.expand_path(script_name, __dir__)
  cmd = [RbConfig.ruby, script_path, "--month", month]
  cmd << "--dry-run" if dry_run

  success = system(ENV, *cmd)
  return if success

  abort("Sync failed: #{File.basename(script_name)}")
end

options = parse_options
load_dotenv(File.expand_path("../.env", __dir__))

puts "Target month: #{options[:month]}"
puts "Ruby: #{RbConfig.ruby}"

run_sync("sync_lastfm_month.rb", month: options[:month], dry_run: options[:dry_run])
run_sync("sync_letterboxd_month.rb", month: options[:month], dry_run: options[:dry_run])
