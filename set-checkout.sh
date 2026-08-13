#!/usr/bin/env bash
# set-checkout.sh: flip the $1 checkout LIVE in one command.
# Usage: ./set-checkout.sh "<HighLevel order-form URL>"
# Sets CHECKOUT_URL in index.html, commits, and pushes to GitHub Pages.
# Reusable per module (run from that module's site/ dir). Re-running with a new URL just updates it.
set -euo pipefail
cd "$(dirname "$0")"

URL="${1:-}"
if [ -z "$URL" ]; then echo "usage: $0 \"<checkout URL>\""; exit 1; fi
case "$URL" in http://*|https://*) ;; *) echo "refusing: URL must start with http(s)://"; exit 1;; esac

# Swap the CHECKOUT_URL constant (line: const CHECKOUT_URL = "...";)
# BSD sed (macOS) requires the '' after -i.
sed -i '' -E "s|const CHECKOUT_URL = \"[^\"]*\";|const CHECKOUT_URL = \"${URL//|/\\|}\";|" index.html

grep -q "const CHECKOUT_URL = \"$URL\";" index.html || { echo "FAILED to set CHECKOUT_URL"; exit 1; }
echo "CHECKOUT_URL set -> $URL"

git add index.html
git commit -m "Activate \$1 checkout (CHECKOUT_URL live)" >/dev/null
git push origin main
echo "pushed. Pages will serve the live checkout in ~1 min."
