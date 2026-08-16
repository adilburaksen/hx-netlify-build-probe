#!/usr/bin/env bash
# Read-only reconnaissance of the Netlify build sandbox.
# The program invites exactly this: privilege escalation to root, secrets not already accessible to
# this user, container escape, and orchestration control-plane access. Nothing here writes, deletes,
# or sends data anywhere; every line only reports what this container can already see.
say(){ printf '\n===== %s =====\n' "$1"; }

say "identity"
id 2>&1; echo "whoami=$(whoami 2>&1)"; echo "uid=$(id -u 2>&1)"

say "kernel and container runtime"
uname -a 2>&1
cat /proc/1/cgroup 2>&1 | head -12
cat /proc/self/status 2>&1 | grep -Ei 'CapEff|CapPrm|Seccomp|NoNewPrivs' || true
echo "--- /.dockerenv:"; ls -la /.dockerenv 2>&1 || echo none

say "privileged devices and sockets"
ls -la /var/run/docker.sock /run/docker.sock 2>&1 || echo "no docker socket"
ls -la /dev/kmsg /dev/mem /dev/sd* /dev/nvme* 2>&1 | head -8 || echo "no raw devices"

say "kubernetes service account"
ls -la /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1 || echo "no k8s serviceaccount mount"
env | grep -i kubernetes 2>&1 || echo "no KUBERNETES_* env"

say "mounts"
mount 2>&1 | head -25

say "cloud metadata reachability (read-only, no credential use)"
for u in "http://169.254.169.254/latest/meta-data/" \
         "http://169.254.169.254/computeMetadata/v1/?recursive=false" \
         "http://metadata.google.internal/computeMetadata/v1/?recursive=false"; do
  echo "--- $u"
  curl -s -m 4 -o /dev/null -w '   http=%{http_code} time=%{time_total}\n' "$u" 2>&1 || echo "   unreachable"
done

say "environment variable names only (values redacted)"
env | sed 's/=.*/=<redacted>/' | sort | head -60

say "network position"
ip addr 2>&1 | grep -E 'inet |^[0-9]+:' | head -12
cat /etc/resolv.conf 2>&1 | head -6
echo "--- egress check to a public host:"
curl -s -m 5 -o /dev/null -w '   example.com http=%{http_code}\n' https://example.com 2>&1 || true

say "internal service reachability (connect only, nothing sent)"
for hp in "169.254.169.254:80" "127.0.0.1:2375" "10.0.0.1:443"; do
  h=${hp%:*}; p=${hp#*:}
  timeout 3 bash -c "echo > /dev/tcp/$h/$p" 2>/dev/null && echo "   OPEN  $hp" || echo "   closed $hp"
done

say "done"
