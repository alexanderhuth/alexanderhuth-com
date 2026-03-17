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
    {% assign plain_lead = entry.lead | remove: '**' %}
    {% assign entry_title = entry.lead | markdownify | remove: '<p>' | remove: '</p>' %}
    {% assign entry_meta = entry.meta %}
    {% if entry.type == 'film' and entry_meta %}
      {% assign entry_meta = entry_meta | remove_first: 'dir. ' %}
    {% endif %}
    {% if entry.type == 'tv' %}
      {% assign show_title = entry.show_title | default: plain_lead | split: ' (' | first %}
      {% assign episode_title = entry.episode_title | default: entry.meta %}
      {% assign season_number = entry.season_number | default: plain_lead | split: 'Season ' | last | split: ',' | first | strip %}
      {% assign episode_number = entry.episode_number | default: plain_lead | split: 'Episode ' | last | split: ')' | first | strip %}
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
