#!/usr/bin/env bash
# Pass 6, single question: what IS /opt/build/env_store/.env? It has no KEY=VALUE lines, contains no
# account or site identifiers, is world-readable, and grows by ~11 KB on every build. Characterise
# the format and check whether any of it belongs to someone other than us. Values are not printed.
say(){ printf '\n===== %s =====\n' "$1"; }
ME="${ACCOUNT_ID:-noacct}"
for f in /opt/build/env_store/.env /rom/overlay/prev/opt/build/env_store/.env; do
  say "$f"
  [ -r "$f" ] || { echo "   unreadable"; continue; }
  ls -l "$f"; echo "   bytes=$(wc -c <"$f")  lines=$(wc -l <"$f")"
  echo "--- file type:"; file "$f" 2>&1 | head -2
  echo "--- first 240 bytes, hex:"; head -c 240 "$f" 2>/dev/null | od -c 2>/dev/null | head -12
  echo "--- printable ratio: $(head -c 4000 "$f" | tr -dc '[:print:]\n' | wc -c) of 4000"
  echo "--- distinct line prefixes:"
  cut -c1-24 "$f" 2>/dev/null | sort | uniq -c | sort -rn | head -10
  echo "--- does it mention netlify hosts, tokens, or emails?"
  grep -aoiE '[a-z0-9-]+\.netlify\.(app|com)' "$f" 2>/dev/null | sort -u | head -6
  grep -aoiE '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' "$f" 2>/dev/null | sort -u | head -6
  grep -aoiE '(secret|token|password|private_key|authorization)' "$f" 2>/dev/null | sort | uniq -c | head -6
  echo "--- our own markers present?"
  grep -ac "$ME" "$f" 2>/dev/null | sed 's/^/   ACCOUNT_ID hits: /'
  grep -ac "${SITE_ID:-nosite}" "$f" 2>/dev/null | sed 's/^/   SITE_ID hits: /'
  grep -ac 'hx-netlify-build-probe' "$f" 2>/dev/null | sed 's/^/   our repo hits: /'
done
say "for contrast, what does env_store hold besides .env"
ls -la /opt/build/env_store/ 2>&1 | head -12
say "done"
