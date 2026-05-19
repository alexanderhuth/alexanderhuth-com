# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Jekyll static site (Ruby 3.4.x). Content authored in Markdown, templated with Liquid, built to static HTML, deployed automatically via GitHub webhook to statichost.eu.

## Commands

```bash
bundle install
bundle exec jekyll serve         # http://localhost:4000
bundle exec jekyll build
bundle exec jekyll clean
```

## Detailed Guidelines

- [Commands & deployment](_docs/commands.md)
- [Content, front matter & file naming](_docs/content.md)
- [CSS architecture & theming](_docs/theming.md)
- [Meet booking system](_docs/meet.md)
- [Media sync workflow](_docs/media-sync.md)
- [Photos feed](_docs/photos.md)
