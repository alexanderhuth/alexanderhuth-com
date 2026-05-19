# Commands

```bash
bundle install                   # Install Ruby dependencies
bundle exec jekyll serve         # Dev server at http://localhost:4000
bundle exec jekyll build         # Production build to _site/
bundle exec jekyll clean         # Remove build artifacts
```

Ruby version: 3.4.x (match statichost.eu build image).

## Deployment

statichost.eu pulls from the `main` branch via GitHub webhook and builds automatically. No CI/CD configuration needed.

## Testing

No automated tests. Verify changes by running `bundle exec jekyll serve` and checking affected pages manually. Test the random theme selector by refreshing pages, and verify responsive design at different viewport sizes.
