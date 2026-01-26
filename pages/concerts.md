---
layout: page
title: Concerts
permalink: /concerts/
---

# Concerts

{% assign show_count = site.data.concerts | size %}
{% assign artist_count = site.data.concerts | map: "artist" | uniq | size %}

A list of all {{ show_count }} live performances by {{ artist_count }} bands and artistst I have attended over the years.

{% assign shows = site.data.concerts | sort: "date" | reverse %}
{% assign grouped = shows | group_by_exp: "show", "show.date | date: '%Y'" %}

<p class="concert-index">{%- for year in grouped -%}{% if forloop.index0 > 0 %}, {% endif %}<a href="#{{ year.name | slugify }}">{{ year.name }}</a>{%- endfor -%}</p>

{% for year in grouped %}
  {% assign gigs = year.items.size %}
  {% assign cities = year.items | map: "city" | uniq %}
  {% assign city_label = 'cities' %}
  {% if cities.size == 1 %}
    {% assign city_label = 'city' %}
  {% endif %}
  <h2 id="{{ year.name | slugify }}">{{ year.name }}</h2>
  <p class="concert-meta"><em>Attended {{ gigs }} gigs in {{ cities.size }} {{ city_label }}.</em></p>

  <ul>
    {% for show in year.items %}
      {% assign place = show.festival | default: show.venue %}
      <li>
        {% if show.festival %}
          <a href="{{ show.setlist_url }}">{{ show.artist }} at {{ show.festival }}</a>
          · {{ show.date | date: "%b %-d" | replace: " ", "&nbsp;" }}
        {% else %}
          <a href="{{ show.setlist_url }}">{{ show.artist }} at {{ place }}</a>
          · {{ show.city }} · {{ show.date | date: "%b %-d" | replace: " ", "&nbsp;" }}
        {% endif %}
      </li>
    {% endfor %}
  </ul>
{% endfor %}
