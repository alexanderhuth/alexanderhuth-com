---
layout: page
title: Media
description: Things I am watching, reading, and listening to.
permalink: /media/
---

# My Media Diet

{% assign entries = site.data.media.entries %}
{% assign months = entries | map: "month" | uniq %}

{% for month in months %}
## {{ month }}

<table class="media-table" aria-label="{{ month }} media entries">
  <tbody>
  {% for entry in entries %}
  {% if entry.month == month %}
    {% assign entry_title = '' %}
    {% assign entry_meta = '' %}
    {% if entry.type == 'film' %}
      {% capture film_title %}
        <strong>{{ entry.title }}</strong>{% if entry.year %} ({{ entry.year }}){% endif %}
      {% endcapture %}
      {% assign entry_title = film_title | strip %}
      {% assign entry_meta = entry.director | default: '' %}
    {% endif %}
    {% if entry.type == 'music' %}
      {% capture music_title %}
        <strong>{{ entry.album }}</strong>{% if entry.year %} ({{ entry.year }}){% endif %}
      {% endcapture %}
      {% assign entry_title = music_title | strip %}
      {% assign entry_meta = entry.artist | default: '' %}
    {% endif %}
    {% if entry.type == 'tv' %}
      {% assign show_title = entry.show_title %}
      {% assign episode_title = entry.episode_title %}
      {% assign season_number = entry.season_number %}
      {% assign episode_number = entry.episode_number %}
      {% capture season_episode_code %}
        S{{ season_number | plus: 0 | prepend: '00' | slice: -2, 2 }} E{{ episode_number | plus: 0 | prepend: '00' | slice: -2, 2 }}
      {% endcapture %}
      {% capture tv_title %}
        <strong>{{ show_title }}</strong>{% if season_number and episode_number %} · {{ season_episode_code | strip }}{% endif %}{% if episode_title %} · {{ episode_title }}{% endif %}
      {% endcapture %}
      {% assign entry_title = tv_title | strip %}
      {% assign entry_meta = '' %}
    {% endif %}
    <tr>
      <td class="media-table-emoji" aria-hidden="true">{{ entry.emoji }}</td>
      <td class="media-table-title">{{ entry_title }}</td>
      <td class="media-table-meta">{% if entry_meta %}{{ entry_meta }}{% endif %}</td>
      <td class="media-table-date">{{ entry.date_display }}</td>
    </tr>
  {% endif %}
  {% endfor %}
  </tbody>
</table>

{% endfor %}
