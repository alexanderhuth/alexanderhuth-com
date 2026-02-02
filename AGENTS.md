---
---
# AGENTS.md

This file contains development guidelines and commands for agentic coding assistants working on this Jekyll static site.

## Project Overview

This is a Jekyll static site hosted on statichost.eu (repo on GitHub with a webhook-triggered pull/build). It's a personal website/blog with a minimal design and random color theme selector.

**Key Technologies:**
- Jekyll (Ruby static site generator)
- Liquid templating
- Markdown content
- CSS with custom properties for theming
- JSON data files for dynamic content

## Development Commands

### Local Development
```bash
# Install dependencies
bundle install

# Start local development server (serves at http://localhost:4000)
bundle exec jekyll serve

# Build the site for production
bundle exec jekyll build

# Clean build artifacts
bundle exec jekyll clean
```

Ruby version: 3.4.x (match statichost.eu build image).

### Testing
This project has no automated tests. Manual testing involves:
1. Run `bundle exec jekyll serve` locally
2. Navigate to different pages to verify layout and functionality
3. Test the random theme selector by refreshing pages
4. Verify responsive design at different viewport sizes
5. Check that all links work correctly

### Deployment
- statichost.eu pulls from the GitHub repo via webhook and builds the site
- No CI/CD configuration needed
- Feeds: `/feed.xml` is a hand-rolled Atom feed (no `jekyll-feed` plugin).

## Code Style Guidelines

### File Organization
```
/
├── _config.yml          # Jekyll configuration
├── Gemfile              # Ruby dependencies
├── index.md             # Homepage
├── assets/              # Static assets (CSS, favicons)
├── _data/               # Data files (JSON)
├── _includes/           # Reusable HTML components
├── _layouts/            # Page templates
├── _posts/              # Blog posts (YYYY-MM-DD-title.md)
├── pages/               # Static pages
└── _site/               # Generated site (build output)
```

### Front Matter (YAML)
**Required fields:**
- `layout`: Must be one of `home`, `page`, `post`
- `title`: Page title (string)

**Optional fields:**
- `description`: Meta description for SEO
- `seo_title`: Override page title for SEO
- `permalink`: Custom URL path
- `robots`: "noindex" to prevent indexing

**Example:**
```yaml
---
layout: page
title: About Me
description: Learn more about Alexander Huth
seo_title: About Alexander Huth
permalink: /about/
---
```

### Content Guidelines

#### Markdown Files
- Use standard GitHub-flavored Markdown
- Line length: ~72 characters for readability
- Use `#` for main headings (h1), `##` for subheadings
- Include proper alt text for images
- Use absolute URLs for internal links (`/page-name/`)

#### Blog Posts
- Filename format: `YYYY-MM-DD-title.md`
- Use `layout: post`
- Include descriptive meta description
- Posts live in `_posts/` directory

#### Pages
- Use `layout: page`
- Store in `pages/` directory
- Include relevant meta information

### HTML/Liquid Templates

#### Includes
- Prefix with descriptive name: `html-head.html`, `header.html`
- Use semantic HTML5 elements
- Include proper ARIA labels for accessibility
- Follow Jekyll/Liquid conventions

#### Layouts
- Keep layouts minimal and reusable
- Use include tags for shared components
- Maintain consistent structure across layouts

**Example layout structure:**
```html
{% include html-start.html %}
  {% include html-head.html %}
  <body>
    {% include header.html %}
    <main role="main">
      {{ content }}
    </main>
    {% include footer.html %}
  </body>
{% include html-end.html %}
```

### CSS Guidelines

#### Architecture
- Single CSS file: `assets/style.css`
- Use CSS custom properties for theming
- Mobile-first responsive design
- Component-based class naming

#### Theming System
- 10 predefined themes in CSS variables
- Random theme selection via JavaScript
- Theme classes: `.sand`, `.amber`, `.seaglass`, `.coral`, `.dawn`, `.royal`, `.forest`, `.ruby`, `.sky`, `.fireball`

#### CSS Conventions
- Use kebab-case for class names
- Logical grouping of related styles
- Consistent spacing and indentation (2 spaces)
- Modern CSS features (CSS Grid, Flexbox, custom properties)

#### Responsive Design
- Max-width container: `72ch`
- Mobile viewport handling with `100dvh`
- Safe area insets for mobile browsers
- Flexible layouts with flexbox/grid

### JavaScript Guidelines

#### Theme Selector
- Minimal JavaScript for theme randomization
- Immediately-invoked function expression pattern
- No external dependencies

#### Code Style
- Use modern ES6+ features when appropriate
- Keep scripts minimal and focused
- Place critical scripts in `<head>`
- Use semantic event handling

### Data Files

#### JSON Structure
- Store in `_data/` directory
- Use consistent naming conventions
- Include relevant metadata
- Maintain valid JSON format

#### Example (concerts.json):
```json
[
  {
    "setlist_id": "unique_id",
    "date": "YYYY-MM-DD",
    "artist": "Artist Name",
    "venue": "Venue Name",
    "city": "City",
    "country": "Country",
    "festival": null,
    "setlist_url": "https://example.com"
  }
]
```

### Accessibility Guidelines

#### HTML Structure
- Use semantic elements (`<main>`, `<header>`, `<footer>`)
- Include proper ARIA labels and roles
- Maintain heading hierarchy (h1-h6)
- Provide alt text for images

#### Navigation
- Keyboard-accessible navigation
- Focus indicators for interactive elements
- Descriptive link text
- Skip links for content navigation

#### Color & Contrast
- Ensure sufficient contrast ratios
- Don't rely on color alone for information
- Test with different themes

### SEO Best Practices

#### Meta Tags
- Include descriptive titles and descriptions
- Use proper Open Graph tags
- Set canonical URLs
- Control indexing with robots meta

#### URL Structure
- Use clean, descriptive URLs
- Implement proper redirects when needed
- Maintain consistent URL patterns

#### Content
- Use proper heading structure
- Include alt text for images
- Write descriptive meta descriptions
- Use semantic HTML

## Common Tasks

### Adding a New Page
1. Create `.md` file in `pages/` directory
2. Add front matter with `layout: page`
3. Write content in Markdown
4. Test locally

### Meet Booking System
- Layout: `_layouts/meet.html` (wraps content and injects meet config + `assets/meet.js`)
- Shared UI include: `_includes/meet-ui.html` (slots + booking form)
- Script: `assets/meet.js` (availability fetch, slot rendering, booking POST, validation)
- Global config: `_config.yml` under `meet:` (working hours, blocks, notice window, durations, buffer)
- Public config endpoint: `/meet-config.json` (generated from `meet-config.json`, used by n8n as source of truth)
- Turnstile site key: `_config.yml` under `meet.turnstile_site_key` (leave empty to disable widget)
- Per-page overrides: front matter keys `meet_duration` and optional `meet_copy_*`
- Pages:
  - `pages/meet.md` (main page with duration selector)
  - `pages/meet-15.md`, `pages/meet-30.md`, `pages/meet-60.md` (fixed duration, `robots: noindex`)
- Slashes list excludes `/meet/15/`, `/meet/30/`, `/meet/60/` in `pages/slashes.md`

#### Meet Security Notes
- Do not put shared secrets in `assets/meet.js` or HTML.
- Availability returns `start_iso`/`end_iso` + `slot_token`; booking must send those ISO values.
- n8n should enforce min notice, slot validity, and rate limiting server-side.

### Photos Feed
- Page: `pages/photos.md` (`/photos/`) uses `theme: sand` to force the lightest background.
- Data: photos collection in `_photos/` (sorted by date + time; the page slices to 50 items).
- Images: store 1920px detail files in `/images/`, 1280px feed files in `/images/1280/`, and responsive variants in `/images/960/`, `/images/720/`, `/images/480/`.
- Fields per entry: `date`, `time`, `title`, `alt`, `image`, `width`, `height`, optional `location`, `robots`.
- Responsive images (feed): `srcset` uses 480/720/960/1280 with `sizes="(max-width: 48rem) 100vw, calc(72ch + 3rem)"`.
- Loading behavior: first image uses `loading="eager"` + `fetchpriority="high"`; others are `loading="lazy"`, all use `decoding="async"`.
- Date links to the photo detail page; image itself is not linked.
- Feed: root-level Atom feed at `/photos.xml` (linked in the global `<head>`), embeds the 720px variant.
- Photo pages: generated from the `photos` collection in `_photos/`, use `_layouts/photo.html`, default to `theme: sand` via `_config.yml` defaults, and set `robots: noindex`.

### Adding a Blog Post
1. Create file in `_posts/` with format `YYYY-MM-DD-title.md`
2. Add front matter with `layout: post`
3. Write content in Markdown
4. Test locally

### Modifying Styles
1. Edit `assets/style.css`
2. Test with different themes
3. Verify responsive behavior
4. Check accessibility

### Adding New Theme
1. Add new theme class in `assets/style.css`
2. Define CSS custom properties for colors
3. Add theme name to JavaScript array in `html-head.html`
4. Test across different pages

## File Naming Conventions

- **Pages**: `kebab-case.md` (e.g., `about-me.md`)
- **Posts**: `YYYY-MM-DD-kebab-case.md` (e.g., `2024-01-15-my-post.md`)
- **Includes**: `kebab-case.html` (e.g., `html-head.html`)
- **Layouts**: `kebab-case.html` (e.g., `default.html`)
- **Assets**: Use existing naming patterns

## Git Workflow

- Main branch: `main`
- statichost.eu pulls and builds from `main` via webhook
- No pull request requirements (personal project)
- Commit messages should be descriptive and concise

## Dependencies

### Ruby Gems
- `jekyll`: Static site generator
- `webrick`: Required for local `jekyll serve` on modern Ruby

### No External Dependencies
- No JavaScript libraries/frameworks
- No CSS preprocessors
- No build tools beyond Jekyll

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- Mobile browsers (iOS Safari, Chrome Mobile)
- Graceful degradation for older browsers
- Progressive enhancement approach

## Security Considerations

- No user input processing
- No server-side code beyond Jekyll
- No external API calls
- statichost.eu handles security/SSL

## Performance

- Minimal asset size
- No JavaScript frameworks
- Optimized images
- Fast loading times
- Efficient CSS with custom properties
