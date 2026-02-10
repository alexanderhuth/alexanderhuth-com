---
layout: page
title: Slashes
seo_title: Slash Pages
permalink: /slashes/
---

# Slash Pages

<ul>
  {% for page in site.pages %}
    {% unless page.url == "/" or page.url == "/slashes/" or page.url == "/meet/" or page.url == "/meet/15/" or page.url == "/meet/30/" or page.url == "/meet/60/" or page.url == "/meet-config.json" or page.url == "/404.html" or page.url == "/feed.xml" or page.url == "/photos.xml" or page.url == "/sitemap.xml" or page.url contains "/assets/" or page.path contains "_posts" %}
      <li><a href="{{ page.url }}">/{{ page.title | downcase }}</a></li>
    {% endunless %}
  {% endfor %}
</ul>
