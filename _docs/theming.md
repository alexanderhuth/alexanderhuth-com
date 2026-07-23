# Theming

## Architecture

Single CSS file: `assets/style.css`. No preprocessor. Mobile-first, responsive. Max-width container: `72ch`.

## Themes

14 named themes defined as CSS custom properties on a class selector (e.g. `.mustard { --bg-color: …; --text-color: …; }`). Defaults live in `:root` and match `sand` — no `.sand` class is needed.

13 themes in the random rotator: `mustard`, `seaglass`, `coral`, `terracotta`, `slate`, `royal`, `forest`, `ruby`, `sky`, `lilac`, `plum`, `fireball`, plus the `:root` default (surfaced by JS as `sand`).

1 special theme (not in rotator, only via front matter): `.letterboxd`

## How Randomization Works

An IIFE in `_includes/html-head.html` runs before the DOM renders and sets a class on the `<html>` element. To force a theme on a page, add `theme: <name>` to the page's front matter.

## Adding a New Theme

1. Add a new class in `assets/style.css` with the required CSS custom properties.
2. Add the theme name to the JavaScript array in `_includes/html-head.html` (if it should appear in the random rotator).

## CSS Conventions

- Kebab-case class names
- 2-space indentation
- CSS Grid and Flexbox for layout
- `100dvh` and safe area insets for mobile
