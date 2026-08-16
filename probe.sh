#!/usr/bin/env bash
# Pass 4. Pass 3 established that /rom/overlay/prev held OUR OWN previous build. The open question is
# whether that snapshot device is ever recycled from a DIFFERENT tenant's build without being wiped.
# This probe leaves an account-stamped canary in the paths that survive into the snapshot, and looks
# for any canary that is not ours. Read-only apart from our own canary files.
say(){ printf '\n===== %s =====\n' "$1"; }
ME="${ACCOUNT_ID:-noacct}"

say "who am I this run"
echo "ACCOUNT_ID=$ME"
echo "SITE_ID=${SITE_ID:-?}  BUILD_ID=${BUILD_ID:-?}  SITE_NAME=${SITE_NAME:-?}"
echo "HOST_NODE_IP=${HOST_NODE_IP:-unset}"
echo "vdd: $(ls -l /dev/vdd 2>&1)"

say "what persists in the previous snapshot's build home"
ls -la /rom/overlay/prev/opt/buildhome/.ssh/ 2>&1 | head -10
echo "--- .ssh file sizes only, contents NOT printed:"
find /rom/overlay/prev/opt/buildhome/.ssh -type f -printf '%M %10s %p\n' 2>/dev/null
echo "--- gitconfig (ours, safe to show):"
cat /rom/overlay/prev/opt/buildhome/.gitconfig 2>&1 | head -12
echo "--- build cache:"
ls -la /rom/overlay/prev/opt/build/cache/ 2>&1 | head -12
echo "--- env_store:"
ls -la /rom/overlay/prev/opt/build/env_store/ 2>&1 | head -12

say "THE TEST — any canary in the snapshot that is not ours?"
FOUND=$(find /rom/overlay/prev -maxdepth 8 -name 'hxcanary-*' 2>/dev/null)
if [ -z "$FOUND" ]; then
  echo "   no canary present in the snapshot"
else
  for f in $FOUND; do
    echo "   found: $f"
    C=$(cat "$f" 2>/dev/null | head -2)
    echo "      $C"
    case "$C" in
      *"$ME"*) echo "      -> OURS (account $ME)";;
      *)       echo "      -> *** NOT OURS — CROSS-TENANT SNAPSHOT REUSE ***";;
    esac
  done
fi

say "does the snapshot hold a repo that is not ours?"
cat /rom/overlay/prev/opt/build/repo/README.md 2>&1 | head -4
git -C /rom/overlay/prev/opt/build/repo config --get remote.origin.url 2>&1 | head -2
git -C /rom/overlay/prev/opt/build/repo log --oneline -3 2>&1 | head -4

say "leave our stamped canary where it will persist"
for d in /opt/buildhome /opt/build/cache; do
  printf 'hxcanary account=%s site=%s build=%s stamp=%s\n' \
    "$ME" "${SITE_ID:-?}" "${BUILD_ID:-?}" "$(date -u +%FT%TZ)" \
    > "$d/hxcanary-$ME.txt" 2>/dev/null \
    && echo "   wrote $d/hxcanary-$ME.txt" || echo "   could not write in $d"
done

say "done"
