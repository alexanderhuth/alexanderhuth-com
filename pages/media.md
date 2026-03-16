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

<ul class="emoji-list">
{% for entry in entries %}
{% if entry.month == month %}
  <li>{{ entry.emoji }} {{ entry.lead | markdownify | remove: '<p>' | remove: '</p>' }}{% if entry.meta %} · {{ entry.meta }}{% endif %} · {{ entry.date_display }}</li>
{% endif %}
{% endfor %}
</ul>

{% endfor %}
