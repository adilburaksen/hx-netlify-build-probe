#!/usr/bin/env bash
# Pass 5. Narrow: the previous build's snapshot carries /opt/build/env_store/.env at 22 KB, mode 644,
# readable by buildbot, on a site that has no custom environment variables of its own. Establish what
# is in it WITHOUT printing secret values: key names, sizes, and whether any key or value references
# an account, site, or repository that is not ours.
say(){ printf '\n===== %s =====\n' "$1"; }
ME="${ACCOUNT_ID:-noacct}"; MYSITE="${SITE_ID:-nosite}"
E=/rom/overlay/prev/opt/build/env_store/.env
L=/opt/build/env_store/.env

say "identity of this run"
echo "ACCOUNT_ID=$ME SITE_ID=$MYSITE SITE_NAME=${SITE_NAME:-?}"

for f in "$E" "$L"; do
  say "env_store file: $f"
  if [ ! -r "$f" ]; then echo "   not readable / absent"; continue; fi
  ls -l "$f" 2>&1
  echo "   lines=$(wc -l <"$f" 2>/dev/null) bytes=$(wc -c <"$f" 2>/dev/null)"
  echo "--- key names only, values withheld:"
  grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$f" 2>/dev/null | tr -d '=' | sort -u | head -80
  echo "--- how many keys: $(grep -cE '^[A-Za-z_][A-Za-z0-9_]*=' "$f" 2>/dev/null)"
  echo "--- largest keys by value length:"
  awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/{k=$1; v=length($0)-length($1)-1; print v, k}' "$f" 2>/dev/null \
    | sort -rn | head -8
  echo "--- does it name an account/site/repo that is NOT ours?"
  ACC=$(grep -oE '[0-9a-f]{24}' "$f" 2>/dev/null | sort -u | head -12)
  echo "   24-hex ids present: $(echo "$ACC" | tr '\n' ' ')"
  for a in $ACC; do [ "$a" = "$ME" ] && echo "      $a -> ours" || echo "      $a -> *** NOT OUR ACCOUNT_ID ***"; done
  SIT=$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$f" 2>/dev/null | sort -u | head -12)
  echo "   uuids present: $(echo "$SIT" | tr '\n' ' ')"
  for s in $SIT; do [ "$s" = "$MYSITE" ] && echo "      $s -> ours" || echo "      $s -> *** NOT OUR SITE_ID ***"; done
  echo "   github repos named: $(grep -oE 'github\.com[:/][A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "$f" 2>/dev/null | sort -u | head -6 | tr '\n' ' ')"
  echo "   other netlify sites named: $(grep -oiE '[a-z0-9-]+\.netlify\.app' "$f" 2>/dev/null | sort -u | head -6 | tr '\n' ' ')"
done

say "the same question for the previous build home"
echo "--- .ssh contents (names and sizes only):"
find /rom/overlay/prev/opt/buildhome/.ssh -type f -printf '%M %10s %p\n' 2>/dev/null
echo "--- known_hosts hosts (not keys):"
cut -d' ' -f1 /rom/overlay/prev/opt/buildhome/.ssh/known_hosts 2>/dev/null | sort -u | head -6
echo "--- git credentials present?"
ls -la /rom/overlay/prev/opt/buildhome/.git-credentials 2>&1 | head -3

say "leave our stamped canary again"
for d in /opt/buildhome /opt/build/cache /opt/build/env_store; do
  printf 'hxcanary account=%s site=%s\n' "$ME" "$MYSITE" > "$d/hxcanary-$ME.txt" 2>/dev/null \
    && echo "   wrote $d/hxcanary-$ME.txt" || echo "   could not write in $d"
done

say "done"
