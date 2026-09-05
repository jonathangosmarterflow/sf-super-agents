#!/usr/bin/env bash
# sync-agent.sh: publish the CURRENT prompt from AGENT.md into the hosted builder page.
#
# Source of truth : skills/review-engine/module1-super-agent-builder/AGENT.md
# Destination     : site/get-mab-x7k2/index.html  ->  <pre id="promptTarget">
# Also updates    : the visible "Last updated: YYYY-MM-DD" stamp (id="lastUpdated")
#
# Usage:  ./sync-agent.sh                  # sync from the default AGENT.md, stamp = today
#         ./sync-agent.sh /path/AGENT.md   # sync from another file
#         AGENT_MD=/path/AGENT.md ./sync-agent.sh
#
# Idempotent: re-running with an unchanged AGENT.md leaves the page byte-identical.
# It takes the BODY of AGENT.md (everything after the first standalone '---' line), strips
# em dashes (house rule: never an em dash in anything a human reads), and HTML-escapes it.
set -euo pipefail
cd "$(dirname "$0")"

AGENT_MD="${1:-${AGENT_MD:-$HOME/.claude/skills/review-engine/module1-super-agent-builder/AGENT.md}}"
PAGE="get-mab-x7k2/index.html"

[ -f "$AGENT_MD" ] || { echo "sync-agent: source not found: $AGENT_MD"; exit 1; }
[ -f "$PAGE" ]     || { echo "sync-agent: page not found: $PAGE"; exit 1; }

python3 - "$AGENT_MD" "$PAGE" <<'PYEOF'
import datetime, html, re, sys

src_path, page_path = sys.argv[1], sys.argv[2]
raw = open(src_path, encoding="utf-8").read()

# Body = everything after the first standalone '---' line (the AGENT.md header), else the whole file.
lines = raw.split("\n")
start = 0
for i, ln in enumerate(lines):
    if ln.strip() == "---":
        start = i + 1
        break
body = "\n".join(lines[start:]).strip("\n")

# House rule: no em dashes anywhere a human reads. Normalize before escaping.
EMDASH, ENDASH, NBSP = "\u2014", "\u2013", "\u00a0"
body = body.replace(" " + EMDASH + " ", ", ").replace(EMDASH + " ", ", ").replace(" " + EMDASH, ",").replace(EMDASH, ", ")
body = body.replace(ENDASH, "-").replace(NBSP, " ")

escaped = html.escape(body, quote=False)  # & < >  (quotes are safe inside <pre>)

page = open(page_path, encoding="utf-8").read()

pre_re = re.compile(r'(<pre[^>]*id="promptTarget"[^>]*>)(.*?)(</pre>)', re.S)
if not pre_re.search(page):
    sys.exit("sync-agent: <pre id=\"promptTarget\"> not found in " + page_path)
page = pre_re.sub(lambda m: m.group(1) + escaped + m.group(3), page, count=1)

today = datetime.date.today().isoformat()
stamp_re = re.compile(r'(id="lastUpdated"[^>]*>)Last updated: [^<]*(</span>)')
if not stamp_re.search(page):
    sys.exit("sync-agent: lastUpdated stamp not found in " + page_path)
page = stamp_re.sub(lambda m: m.group(1) + "Last updated: " + today + m.group(2), page, count=1)

if EMDASH in page:
    sys.exit("sync-agent: an em dash survived the sync, refusing to write")

open(page_path, "w", encoding="utf-8").write(page)
print("sync-agent: published %d chars from %s, stamp %s" % (len(escaped), src_path, today))
PYEOF
