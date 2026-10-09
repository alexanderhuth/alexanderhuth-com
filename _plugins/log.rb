# Builds the /log/ page: every dated thing on the site (posts, photos,
# media, concerts, grounds, flights) merged into one timeline, grouped by
# day and split into one page per month at /log/YYYY/MM/. /log/ itself
# holds the most recent month (it gets no dated URL until the next month
# starts). Rendering lives in _includes/log-month.html.

require "date"
require "set"

module SiteLog
  # Nothing older than this makes it into the stream.
  START_DATE = "2026-01-01"

  class MonthPage < Jekyll::PageWithoutAFile
    def initialize(site, dir, month, data)
      super(site, site.source, dir, "index.html")
      self.content = "{% include log-month.html %}\n"
      self.data = data.merge(
        "layout" => "page",
        "title" => month == data["latest_month"] ? "Log" : "Log · #{data["month_label"]}",
        "heading" => "Log",
        "description" => "Everything I posted, watched, listened to and attended in #{data["month_label"]}."
      )
    end
  end

  class Generator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      items = collect(site)
      return if items.empty?

      by_month = items.group_by { |i| i["date"][0, 7] }
      months = by_month.keys.sort.reverse
      latest = months.first

      archive = months.map do |m|
        { "key" => m, "label" => Date.strptime(m, "%Y-%m").strftime("%B %Y"), "url" => month_url(m, latest) }
      end

      months.each_with_index do |month, idx|
        newer = idx.positive? ? months[idx - 1] : nil
        older = months[idx + 1]
        days = by_month[month]
          .group_by { |i| i["date"] }
          .sort.reverse
          .map { |date, day_items| day(date, day_items) }

        data = {
          "month" => month,
          "month_label" => Date.strptime(month, "%Y-%m").strftime("%B %Y"),
          "latest_month" => latest,
          "days" => days,
          "item_count" => by_month[month].size,
          "newer" => newer && { "label" => Date.strptime(newer, "%Y-%m").strftime("%B %Y"), "url" => month_url(newer, latest) },
          "older" => older && { "label" => Date.strptime(older, "%Y-%m").strftime("%B %Y"), "url" => month_url(older, latest) },
          "archive" => archive
        }

        site.pages << MonthPage.new(site, month_url(month, latest).delete_prefix("/"), month, data)
      end
    end

    private

    # One day as the template needs it: posts and photos as-is, everything
    # else pre-grouped so each kind reads as a single sentence.
    def day(date, day_items)
      by_kind = day_items.sort_by { |i| -i["sort"].to_i }.group_by { |i| i["kind"] }
      kind = ->(k) { by_kind[k] || [] }

      shows = kind.("tv").group_by { |i| i["title"] }.map do |title, eps|
        { "title" => title, "episodes" => episode_ranges(eps) }
      end

      films = kind.("film").uniq { |i| i["url"] || i["title"] }

      concerts = kind.("concert").group_by { |i| i["place"] }.map do |place, shows_at|
        { "place" => place, "artists" => shows_at }
      end

      {
        "date" => date,
        "label" => Date.parse(date).strftime("%A, %B %-d"),
        "posts" => kind.("post"),
        "photos" => kind.("photo"),
        "concerts" => concerts,
        "grounds" => kind.("ground"),
        "flights" => kind.("flight"),
        "films" => films.reject { |i| i["cinema"] },
        "cinema" => films.select { |i| i["cinema"] },
        "shows" => shows,
        "albums" => kind.("music").uniq { |i| i["url"] || i["title"] }
      }
    end

    # Consecutive episodes of a season collapse into a range:
    # S01E06, S01E07, S01E08, S02E01 -> ["S01E06–S01E08", "S02E01"]
    def episode_ranges(eps)
      code = ->((season, number)) { format("S%02dE%02d", season, number) }
      eps.map { |e| e["episode"] }.compact.uniq.sort
        .slice_when { |(s1, e1), (s2, e2)| s1 != s2 || e2 != e1 + 1 }
        .map { |run| run.size == 1 ? code.(run.first) : "#{code.(run.first)}–#{code.(run.last)}" }
    end

    def month_url(month, latest = nil)
      return "/log/" if month == latest

      "/log/#{month.sub("-", "/")}/"
    end

    def collect(site)
      items = []

      site.posts.docs.each do |post|
        items << item("post", post.date.strftime("%Y-%m-%d"), post.date.to_i,
                      "title" => post.data["title"], "url" => post.url)
      end

      site.collections["photos"]&.docs&.each do |photo|
        next if photo.data["published"] == false

        items << item("photo", photo.date.strftime("%Y-%m-%d"), photo.date.to_i,
                      "title" => photo.data["title"], "url" => photo.url)
      end

      cinema = Array(site.data["cinema"]).map { |c| c["guid"] }.compact.to_set

      Array(site.data.dig("media", "entries")).each do |e|
        case e["type"]
        when "film"
          items << item("film", e["date"], e["pub_ts"],
                        "title" => e["title"], "year" => e["year"], "by" => e["director"], "url" => e["url"],
                        "cinema" => cinema.include?(e["guid"]))
        when "music"
          items << item("music", e["date"], e["pub_ts"],
                        "title" => e["album"], "year" => e["year"], "by" => e["artist"], "url" => e["url"])
        when "tv"
          ep = [e["season_number"].to_i, e["episode_number"].to_i] if e["season_number"] && e["episode_number"]
          items << item("tv", e["date"], e["pub_ts"],
                        "title" => e["show_title"], "episode" => ep, "url" => e["url"])
        end
      end

      Array(site.data["concerts"]).each do |c|
        place = c["festival"] || [c["venue"], c["city"]].compact.join(", ")
        items << item("concert", c["date"], 0,
                      "title" => c["artist"], "place" => place, "url" => c["setlist_url"])
      end

      Array(site.data["grounds"]).each do |section|
        Array(section["items"]).each do |g|
          items << item("ground", g["date"], 0,
                        "title" => g["match"], "venue" => g["venue"], "city" => g["city"],
                        "competition" => g["competition"])
        end
      end

      Array(site.data["flights"]).each do |section|
        Array(section["items"]).each do |f|
          items << item("flight", f["date"], 0,
                        "from" => f["from_city"], "to" => f["to_city"],
                        "airline" => [f["airline"], f["flight"]].compact.join(" "))
        end
      end

      items.select { |i| i["date"].to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/) && i["date"] >= START_DATE }
    end

    def item(kind, date, sort, fields)
      { "kind" => kind, "date" => date.to_s, "sort" => sort }.merge(fields)
    end
  end
end
