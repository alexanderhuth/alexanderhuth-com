---
layout: page
title: Photos
description: A personal photo feed by Alexander Huth.
permalink: /photos/
theme: sand
---

# Photos
My personal photo feed, newest photos first.

{% assign dates = site.data.photos | map: "date" | uniq | sort | reverse %}
{% if dates and dates.size > 0 %}
  <div class="photo-feed" role="list">
    {% assign rendered = 0 %}
    {% for date in dates %}
      {% assign day_photos = site.data.photos | where: "date", date | sort: "time" | reverse %}
      {% for photo in day_photos %}
        {% if rendered >= 50 %}
          {% break %}
        {% endif %}
        {% assign photo_filename = photo.full | split: "/" | last %}
        {% assign is_first = rendered == 0 %}
        <figure class="photo-card" role="listitem">
          <div class="photo-media" aria-hidden="true">
            <img
              src="{{ "/photos/720/" | append: photo_filename | relative_url }}"
              srcset="{{ "/photos/480/" | append: photo_filename | relative_url }} 480w, {{ "/photos/720/" | append: photo_filename | relative_url }} 720w, {{ "/photos/960/" | append: photo_filename | relative_url }} 960w, {{ photo.full | relative_url }} 1280w"
              sizes="(max-width: 48rem) 100vw, calc(72ch + 3rem)"
              alt="{{ photo.alt | escape }}"
              width="{{ photo.width }}"
              height="{{ photo.height }}"
              loading="{% if is_first %}eager{% else %}lazy{% endif %}"
              decoding="async"
              {% if is_first %}fetchpriority="high"{% endif %}
            >
          </div>
          <figcaption class="photo-meta">
            {% if photo.title %}
              <span class="photo-title">{{ photo.title | escape }}</span>
            {% endif %}
            <span class="photo-date-line">
              <time datetime="{{ photo.date }}T{{ photo.time }}:00+01:00">{{ photo.date | date: "%B %d, %Y" }}</time>
              {% if photo.location %} / <span class="photo-location">{{ photo.location | escape }}</span>{% endif %}
            </span>
          </figcaption>
        </figure>
        {% assign rendered = rendered | plus: 1 %}
      {% endfor %}
      {% if rendered >= 50 %}
        {% break %}
      {% endif %}
    {% endfor %}
  </div>
{% else %}
  <p class="photo-empty">No photos yet. Check back soon.</p>
{% endif %}
