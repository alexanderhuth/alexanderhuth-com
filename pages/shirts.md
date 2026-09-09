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
{% for shirt in shirts %}{% assign tile_loading = "lazy" %}{% if forloop.first %}{% assign tile_loading = "eager" %}{% endif %}{% include grid-tile.html image=shirt.image dir="/images/shirts" w=shirt.width h=shirt.height alt=shirt.alt label=shirt.title back=shirt.back back_alt=shirt.back_alt flip=true full=true loading=tile_loading %}
{% endfor %}</div>

## Notes

{% for shirt in shirts %}{% assign note = shirt.content | strip %}{% if note != "" %}### {{ shirt.title }}

{{ note }}

{% endif %}{% endfor %}
