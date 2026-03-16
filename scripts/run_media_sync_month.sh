#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUBY_BIN="${RUBY_BIN:-$HOME/.rubies/ruby-3.4.8/bin/ruby}"
MONTH="${1:-$(date +%Y-%m)}"

if [[ ! -x "$RUBY_BIN" ]]; then
  echo "Ruby not executable at: $RUBY_BIN" >&2
  exit 1
fi

if [[ -f ".env" ]]; then
  set -a
  source .env
  set +a
fi

echo "Using Ruby: $RUBY_BIN"
echo "Target month: $MONTH"

"$RUBY_BIN" scripts/sync_lastfm_month.rb --month "$MONTH"
"$RUBY_BIN" scripts/sync_letterboxd_month.rb --month "$MONTH"
