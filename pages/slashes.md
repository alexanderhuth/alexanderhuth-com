---
layout: page
title: Slashes
seo_title: Slash Pages
permalink: /slashes/
slashes_exclude: true
---

# Slash Pages

<ul>
  {% for page in site.pages %}
    {% if page.path contains "pages/" and page.slashes_exclude != true %}
      <li><a href="{{ page.url }}">/{{ page.title | downcase }}</a></li>
    {% endif %}
  {% endfor %}
</ul>
