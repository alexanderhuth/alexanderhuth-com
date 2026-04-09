---
layout: post
title: Using Jekyll's Data Files to list concerts
description: A quick note on powering the /concerts page from a JSON data file in Jekyll.
robots: noindex
permalink: /posts/concerts-data/
---

On my [/concerts](/concerts/) page, I list every concert I’ve been to. Instead of manually updating that page, I store all the show details in a single data file by making use of [Jekyll’s Data Files feature](https://jekyllrb.com/docs/datafiles/).

Everything lives in `_data/concerts.json`, with each entry containing the artist, date, venue, city, setlist URL (and. when relevant, a festival name). The page template pulls directly from that file using `site.data.concerts` and renders the list from there.

When the page builds, the template sorts the shows by date, groups them by year, and generates jump links for quick navigation between years. If a `festival` field is present, the festival name is shown instead of the venue automatically.

This setup is intentionally low-maintenance. I update one JSON file, rebuild the site, and the concerts page is regenerated automatically, with no extra tooling or hand-editing required.
