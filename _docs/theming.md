# Theming

## Architecture

Single CSS file: `assets/style.css`. No preprocessor. Mobile-first, responsive.

Layout tokens on `:root`: `--text-width` (`72ch` text column) and `--gutter` (`1.5rem` side padding).

Type tokens on `:root`: `--text-base` (`1.125rem` body size — rem so browser font-size settings apply) and `--text-ratio` (`1.15`). Heading sizes are computed as `base × ratio^step` via `pow()` with positive steps only (h6 = step 0 = body size), so a heading can never be smaller than the text it introduces. `--font-size-sm` is the hand-picked detail size (captions, footer) — small sizes are curated, never derived as negative steps. Figures and the photo grid bleed into the gutter via `calc(-1 * var(--gutter))` margins; the `sizes` default in `_includes/photo-figure.html` mirrors `--text-width + 2 * --gutter` and must be kept in sync by hand.

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
