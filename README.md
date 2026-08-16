# hx-netlify-build-probe

Read-only reconnaissance of the Netlify build sandbox, run against my own Netlify account as part of
authorized security research under Netlify's HackerOne program (researcher `adilburak_`).

`probe.sh` only reports what the build container can already observe about itself. It writes nothing,
deletes nothing, and transmits nothing off the build host.
