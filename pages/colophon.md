---
layout: page
title: Colophon
permalink: /colophon/
---

# Colophon
Notes on how this site is made and served.

Static site powered by Jekyll (via the `github-pages` gem), deployed to GitHub Pages with a custom domain name. There’s no CDN layer, server-side logic, or third-party embeds.  

No tracking, no cookies.  

Content is written in Markdown. Layouts and includes live alongside the pages and posts. The [concerts page](/concerts/) reads structured data from `_data/concerts.json`, while [/slashes/](/slashes/) auto-lists non-post pages.

The [/photos/](/photos/) feed is built from `_data/photos.json` plus image files in `/photos/`, with a dedicated Atom feed at [/photos.xml](/photos.xml).

The slash page itself is inspired by [slashpages.net](https://slashpages.net). Will keep adding slashes over time.

A single handmade stylesheet (`assets/style.css`) handles everything. An inline snippet randomly applies one of the theme classes (`sand`, `amber`, `seaglass` etc.) to rotate background colors. There are no external fonts, client-side frameworks, or build steps for CSS/JS.

Cobbled together in Visual Studio Code and Micro, with a little help from Codex. Built locally with Jekyll, versioned on GitHub, and published as static HTML to GitHub Pages.
