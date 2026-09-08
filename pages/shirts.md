---
layout: page
title: Shirts
description: Most of the band shirts I've owned over time.
permalink: /shirts/
heading: Band Shirts
theme: sand
---

Many of the band shirts I've worn and loved over the years. Most of these aren't part of my wardrobe anymore, but at least there are photos...

{% assign shirts = site.shirts | sort: "order" %}
<div class="photo-grid">
{% for shirt in shirts %}{% include shirt-tile.html shirt=shirt %}{% endfor %}</div>

## Notes

{% for shirt in shirts %}{% assign note = shirt.content | strip %}{% if note != "" %}{% assign slug = shirt.image | split: "/" | last | split: "." | first %}<div class="shirt-note" id="{{ shirt.note_id | default: slug }}" markdown="1">
{{ note }}
</div>

{% endif %}{% endfor %}
