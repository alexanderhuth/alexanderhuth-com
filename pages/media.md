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

{% for entry in entries %}
{% if entry.month == month %}
- {{ entry.emoji }} {{ entry.lead }}{% if entry.meta %} · {{ entry.meta }}{% endif %} · {{ entry.date_display }}
{% endif %}
{% endfor %}
{: .emoji-list}

{% endfor %}
