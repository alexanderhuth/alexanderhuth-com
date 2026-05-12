---
layout: page
title: Colophon
permalink: /colophon/
---

**A few notes on how this site is made and served.**

Static site powered by Jekyll, built on statichost.eu from a GitHub repo via webhook. There’s no CDN layer, server-side logic, or third-party embeds.  

No tracking, no cookies.  

Content is written in Markdown. Layouts and includes live alongside the pages and posts. The [/concerts](/concerts/), [/media](/media/), and [/grounds](/grounds/) pages all read structured data from `_data/`, while the slash page ([/slashes](/slashes/)) auto-lists most pages. It is inspired by [slashpages.net](https://slashpages.net). I'll keep adding slashes over time.

The [/photos](/photos/) feed is built from the `_photos/` collection plus image files in `/images/`, with a dedicated Atom feed at [/photos.xml](/photos.xml).

The charts on the [/letterboxd](/letterboxd/) pages are rendered client-side with [Chart.js](https://www.chartjs.org/), fed from pre-aggregated JSON in `_data/`. No images, no server-side rendering — just data and a script.

The [/meet](/meet/) page is a lightweight booking system. Availability and bookings are handled by an n8n webhook; the page fetches open slots client-side and posts the booking back. Cloudflare Turnstile handles spam protection.

A single handmade stylesheet (`assets/style.css`) handles everything. An inline snippet randomly applies one of the theme classes (`sand`, `amber`, `seaglass` etc.) to rotate background colors. There are no external fonts, client-side frameworks, or build steps for CSS/JS.

Cobbled together in Zed and Micro, with a little help from different LLMs. Built locally with Jekyll, versioned on GitHub, and published as static HTML on [statichost.eu](https://www.statichost.eu).
