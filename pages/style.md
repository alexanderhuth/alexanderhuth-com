---
layout: page
title: Style
seo_title: Style Guide
permalink: /style/
heading: Style Guide
robots: noindex
---

A reference of the design components used across the site.

## Typography

# Heading 1

## Heading 2

### Heading 3

#### Heading 4

##### Heading 5

###### Heading 6

A regular paragraph. The body type is 18px Helvetica Neue / Arial, with a 1.6 line-height and a max width of 72ch. Text is set in `var(--text-color)` against `var(--bg-color)`, both supplied by the active theme class on `<html>`.

**Bold text** uses `<strong>`. *Italic text* uses `<em>`. You can [link to another page](/colophon/) — links are underlined, with the underline removed on hover/focus.

## Figure

Images use the `photo-figure` include which emits a `<figure>` with an `<img>` and an optional `<figcaption>`. The figure pulls slightly wider than the text column on desktop and goes edge-to-edge on mobile.

{% include photo-figure.html slug='hagensche-wiek' w=1920 h=823 alt='Sunset over the Hagensche Wiek shoreline.' caption='Landscape example — Hagensche Wiek at sunset' %}

## Blockquote

> A blockquote sets quoted or attributed text apart with a subtle left border and slightly muted color. Useful for lyrics, epigraphs, or pulled quotes.

## Lists

Unordered list:

- First item
- Second item
  - Nested item
  - Another nested item
- Third item

Ordered list:

1. First step
2. Second step
3. Third step

`.emoji-list` — used on [/contact](/contact/), [/follow](/follow/), and [/now](/now/) to drop the bullet and let an emoji lead each line:

- 📧 Email: [alexander@huth.im](mailto:alexander@huth.im)
- 💼 LinkedIn: [linkedin.com/in/alexanderhuth]({{ site.socials.linkedin }})
- 🍿 Letterboxd: [letterboxd]({{ site.socials.letterboxd }})
- 📆 Meet: [alexanderhuth.com/meet](/meet/){:rel="nofollow"}
{: .emoji-list}

## Tables (media-table)

The `.media-table` layout used on [/media](/media/) and [/grounds](/grounds/). Each row is a CSS grid with emoji, title + meta, and date.

<table class="media-table" aria-label="Example media entries">
  <tbody>
    <tr data-media-type="film">
      <td class="media-table-emoji" aria-hidden="true">🎬</td>
      <td class="media-table-title"><strong>Example Film</strong> (2024)</td>
      <td class="media-table-meta"><span class="media-table-meta-value">Director Name</span></td>
      <td class="media-table-date">May 19</td>
    </tr>
    <tr data-media-type="music">
      <td class="media-table-emoji" aria-hidden="true">🎵</td>
      <td class="media-table-title"><strong>Example Album</strong> (2023)</td>
      <td class="media-table-meta"><span class="media-table-meta-value">Artist Name</span></td>
      <td class="media-table-date">May 18</td>
    </tr>
    <tr data-media-type="tv">
      <td class="media-table-emoji" aria-hidden="true">📺</td>
      <td class="media-table-title"><strong>Example Show</strong></td>
      <td class="media-table-meta"><span class="media-table-meta-value">S01 E03 · Pilot</span></td>
      <td class="media-table-date">May 17</td>
    </tr>
  </tbody>
</table>

## Filter buttons

The inline filter row from [/media](/media/), built from `<button>`s styled to look like text links:

<div class="media-filters" aria-label="Example filters">
  <span class="media-filters-label">Filter by:&nbsp;</span>
  <button class="media-filter-button is-active" type="button" aria-pressed="true">All</button><span class="media-filter-separator">, </span>
  <button class="media-filter-button" type="button" aria-pressed="false">Films</button><span class="media-filter-separator">, </span>
  <button class="media-filter-button" type="button" aria-pressed="false">Music</button><span class="media-filter-separator">, </span>
  <button class="media-filter-button" type="button" aria-pressed="false">TV</button>
</div>

## Code

Inline code looks like `bundle exec jekyll serve`. Block code:

```ruby
def media_sync
  entries = fetch_entries
  entries.map { |e| normalize(e) }
end
```

## Call to action

The `.cta-button` used to drive bookings on [/consulting](/consulting/) and elsewhere:

<p class="cta-wrap">
  <a class="cta-button" href="#" onclick="event.preventDefault()">Schedule a call</a>
</p>

## Logo mark

The four-tile brand mark from the site header, rendered with CSS only:

<div class="logo" aria-hidden="true" style="--size: 1.5rem;">
  <div class="tile"></div>
  <div class="tile rounded"></div>
  <div class="tile split">
    <div class="bar top"></div>
    <div class="bar bottom"></div>
  </div>
  <div class="tile"></div>
</div>

## Theme palette

Background, text, and border colors rotate per page-load via one of these classes on `<html>`:

<ul class="theme-swatches" style="list-style:none;padding:0;margin:0 0 1rem;display:grid;grid-template-columns:repeat(auto-fill,minmax(8rem,1fr));gap:0.5rem;">
  <li class="sand" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">sand</li>
  <li class="mustard" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">mustard</li>
  <li class="seaglass" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">seaglass</li>
  <li class="coral" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">coral</li>
  <li class="terracotta" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">terracotta</li>
  <li class="sky" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">sky</li>
  <li class="lilac" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">lilac</li>
  <li class="plum" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">plum</li>
  <li class="slate" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">slate</li>
  <li class="royal" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">royal</li>
  <li class="forest" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">forest</li>
  <li class="ruby" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">ruby</li>
  <li class="fireball" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">fireball</li>
  <li class="letterboxd" style="background:var(--bg-color);color:var(--text-color);border:1px solid var(--border-color);padding:0.6rem 0.75rem;border-radius:6px;">letterboxd</li>
</ul>

