---
layout: page
title: Photos
description: A personal photo feed by Alexander Huth.
permalink: /photos/
theme: sand
---

# Photos

{% assign photos = site.data.photos | sort: "date" | reverse | slice: 0, 50 %}
{% if photos and photos.size > 0 %}
  <div class="photo-feed" role="list">
    {% for photo in photos %}
      {% assign photo_id = photo.full | split: "/" | last | split: "." | first %}
      {% assign photo_filename = photo.full | split: "/" | last %}
      {% assign is_first = forloop.first %}
      <figure class="photo-card" role="listitem" id="{{ photo_id }}">
        <div class="photo-media" aria-hidden="true">
          <img
            src="{{ "/photos/720/" | append: photo_filename | relative_url }}"
            srcset="{{ "/photos/480/" | append: photo_filename | relative_url }} 480w, {{ "/photos/720/" | append: photo_filename | relative_url }} 720w, {{ "/photos/960/" | append: photo_filename | relative_url }} 960w, {{ photo.full | relative_url }} 1440w"
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
            <a class="photo-link" href="{{ photo.full | relative_url }}"><time datetime="{{ photo.date }}">{{ photo.date | date: "%B %d, %Y" }}</time></a>
            {% if photo.location %} / <span class="photo-location">{{ photo.location | escape }}</span>{% endif %}
          </span>
        </figcaption>
      </figure>
    {% endfor %}
  </div>
{% else %}
  <p class="photo-empty">No photos yet. Check back soon.</p>
{% endif %}
