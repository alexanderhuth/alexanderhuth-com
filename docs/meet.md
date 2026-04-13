# Meet Booking System

## Files

| File | Purpose |
|---|---|
| `_layouts/meet.html` | Layout — wraps content, injects config and `meet.js` |
| `_includes/meet-ui.html` | Shared UI — slot list and booking form |
| `assets/meet.js` | Client logic — availability fetch, slot rendering, booking POST, validation |
| `meet-config.json` | Public config endpoint at `/meet-config.json` (used by n8n as source of truth) |

## Configuration

Global config lives under `meet:` in `_config.yml` (working hours, blocks, notice window, durations, buffer, Turnstile site key). Leave `turnstile_site_key` empty to disable the widget.

Per-page overrides via front matter:
- `meet_duration` — override booking duration
- `meet_copy_*` — override copy strings

## Pages

- `pages/meet.md` — main page with duration selector
- `pages/meet-15.md`, `pages/meet-30.md`, `pages/meet-60.md` — fixed-duration pages (`robots: noindex`; excluded from the slashes list)

## Backend

Availability and booking are handled by an n8n webhook at `https://n8n.alexanderhuth.com/webhook/meet-availability`. The availability response returns `start_iso`, `end_iso`, and a `slot_token`; the booking POST must include those ISO values.

n8n enforces minimum notice, slot validity, and rate limiting server-side. Do not put shared secrets in `assets/meet.js` or any HTML template.
