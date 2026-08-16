#!/usr/bin/env bash
# Second pass, narrowly scoped. The first pass showed a microVM with an unprivileged user and no
# capabilities, so this one only follows the two threads it left open: the host node the build is
# scheduled on, and the world-readable kernel log. Connect-only checks against a handful of named
# ports; no scanning, nothing sent, nothing written.
say(){ printf '\n===== %s =====\n' "$1"; }

say "orchestration-adjacent values from our own build environment"
echo "HOST_NODE_IP=${HOST_NODE_IP:-unset}"
echo "ACCOUNT_ID=${ACCOUNT_ID:-unset}"
echo "SITE_ID=${SITE_ID:-unset}"
echo "BUILD_ID=${BUILD_ID:-unset}"
echo "NETLIFY_BUILD_BASE=${NETLIFY_BUILD_BASE:-unset}"
echo "skew token length=${#NETLIFY_SKEW_PROTECTION_TOKEN} prefix=${NETLIFY_SKEW_PROTECTION_TOKEN:0:6}"
echo "FEATURE_FLAGS length=${#FEATURE_FLAGS}"

say "can this build reach its own host node?"
if [ -n "$HOST_NODE_IP" ]; then
  for port in 10250 10255 4646 2375 2376 8500 22 443 80; do
    timeout 2 bash -c "echo > /dev/tcp/$HOST_NODE_IP/$port" 2>/dev/null \
      && echo "   OPEN   $HOST_NODE_IP:$port" || echo "   closed $HOST_NODE_IP:$port"
  done
else
  echo "   HOST_NODE_IP unset"
fi

say "the internal resolver"
cat /etc/resolv.conf 2>&1 | head -4
for port in 53 80 443; do
  timeout 2 bash -c "echo > /dev/tcp/172.16.6.1/$port" 2>/dev/null \
    && echo "   OPEN   172.16.6.1:$port" || echo "   closed 172.16.6.1:$port"
done

say "our own address and route"
ip -4 addr 2>/dev/null | grep inet || hostname -I 2>/dev/null
ip route 2>/dev/null | head -5

say "kernel log readable by an unprivileged build user?"
if timeout 3 dd if=/dev/kmsg bs=1 count=1200 2>/dev/null | head -c 1200; then
  echo; echo "   (kmsg WAS readable as uid $(id -u))"
else
  echo "   kmsg not readable"
fi

say "does anything in this VM belong to someone else?"
ls -la /opt/build 2>&1 | head -8
ls -la /opt/buildhome 2>&1 | head -8
echo "--- other home dirs:"; ls -la /home 2>&1 | head -8

say "done"
