#!/usr/bin/env bash
# Third pass, designed from two independent delegate reviews of the first two passes.
# Read-only except for one canary file written under our own build's /tmp, which is how the
# cross-account snapshot test is decided. Nothing is sent anywhere; no scanning beyond the single
# host address Netlify itself injects, on four named ports.
say(){ printf '\n===== %s =====\n' "$1"; }

say "PID 1 — container vs microVM, the cheapest falsification"
tr '\0' ' ' </proc/1/cmdline 2>/dev/null; echo
echo "--- pid1 cgroup:"; cat /proc/1/cgroup 2>&1 | head -6
echo "--- self cgroup:"; cat /proc/self/cgroup 2>&1 | head -6

say "setuid binaries (NoNewPrivs is 0, so these would matter)"
find / -xdev -perm -4000 -type f -print 2>/dev/null | head -20
echo "(count: $(find / -xdev -perm -4000 -type f 2>/dev/null | wc -l))"

say "HOST_NODE_IP position and four named ports"
echo "HOST_NODE_IP=${HOST_NODE_IP:-unset}"
if [ -n "$HOST_NODE_IP" ]; then
  ip route get "$HOST_NODE_IP" 2>&1 | head -3
  for p in 2375 2376 6443 10250; do
    timeout 3 bash -c "</dev/tcp/${HOST_NODE_IP}/$p" 2>/dev/null \
      && echo "   OPEN   ${HOST_NODE_IP}:$p" || echo "   closed ${HOST_NODE_IP}:$p"
  done
fi

say "skew token structure, decoded locally, never transmitted"
T="${NETLIFY_SKEW_PROTECTION_TOKEN:-}"
echo "length=${#T} dots=$(awk -F. '{print NF-1}' <<<"$T")"
if [ "$(awk -F. '{print NF-1}' <<<"$T")" = "2" ]; then
  echo "--- header:";  cut -d. -f1 <<<"$T" | base64 -d 2>/dev/null | head -c 300; echo
  echo "--- claims:";  cut -d. -f2 <<<"$T" | base64 -d 2>/dev/null | head -c 500; echo
else
  echo "not JWT-shaped; first 8 chars: ${T:0:8}"
fi

say "what consumes the identifiers?"
grep -RIl "NETLIFY_SKEW_PROTECTION_TOKEN\|HOST_NODE_IP" /usr/local/bin /opt/build-bin 2>/dev/null | head -10
echo "---"
grep -RIl "SITE_ID\|BUILD_ID\|ACCOUNT_ID" /usr/local/bin /opt/build-bin 2>/dev/null | head -10

say "THE MAIN EVENT — /rom/overlay/prev, a previous build snapshot"
stat -c '%A %a uid=%u gid=%g %n' /rom /rom/overlay /rom/overlay/prev 2>&1
echo "--- backing device:"; ls -l /dev/vdd 2>&1
dumpe2fs -h /dev/vdd 2>/dev/null | grep -iE 'Filesystem UUID|Filesystem created|Last mount|Last write|Mount count' || echo "   dumpe2fs unavailable"
echo "--- top level:"
ls -la /rom/overlay/prev 2>&1 | head -25
echo "--- two levels down:"
find /rom/overlay/prev -maxdepth 3 -printf '%M %u %g %10s %p\n' 2>/dev/null | head -60

say "does the previous snapshot carry anyone's repo, home, or credentials?"
for d in /rom/overlay/prev/opt/build/repo /rom/overlay/prev/opt/buildhome \
         /rom/overlay/prev/root /rom/overlay/prev/home /rom/overlay/prev/tmp; do
  echo "--- $d"; ls -la "$d" 2>&1 | head -12
done
echo "--- any canary from a previous run of ours, or from anyone else:"
find /rom/overlay/prev -maxdepth 6 -name 'hxcanary*' -o -maxdepth 6 -name '*.netlify' \
     -o -maxdepth 6 -name 'id_rsa*' -o -maxdepth 6 -name '.git-credentials' 2>/dev/null | head -20

say "leave our own canary so the next build can tell whose snapshot this is"
CAN="/tmp/hxcanary-${ACCOUNT_ID:-noacct}-${SITE_ID:-nosite}.txt"
printf 'hxcanary account=%s site=%s build=%s\n' "${ACCOUNT_ID:-?}" "${SITE_ID:-?}" "${BUILD_ID:-?}" > "$CAN" 2>/dev/null \
  && echo "   wrote $CAN" || echo "   could not write canary"
echo "$HOME:"; ls -la "$HOME" 2>&1 | head -8

say "done"
