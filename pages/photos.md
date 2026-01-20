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
      <figure class="photo-card" role="listitem">
        <div class="photo-link" aria-hidden="true">
          <img
            src="{{ photo.thumb | relative_url }}"
            alt="{{ photo.alt | escape }}"
            loading="lazy"
          >
        </div>
        <figcaption class="photo-meta">
          {% if photo.title %}
            <span class="photo-title">{{ photo.title | escape }}</span>
          {% endif %}
          {% if photo.alt %}
            <em class="photo-description">{{ photo.alt | escape }}</em>
          {% endif %}
          <span class="photo-date-line">
            <a class="photo-date-link" href="{{ photo.full | relative_url }}"><time datetime="{{ photo.date }}">{{ photo.date | date: "%B %d, %Y" }}</time></a>
            {% if photo.location %}<span class="photo-location">/ {{ photo.location | escape }}</span>{% endif %}
          </span>
        </figcaption>
      </figure>
    {% endfor %}
  </div>
{% else %}
  <p class="photo-empty">No photos yet. Check back soon.</p>
{% endif %}
