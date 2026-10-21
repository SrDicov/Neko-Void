#!/bin/bash
#
# Wrapper de xbps-install para mklive.
#
# xbps >= 0.60 ignora XBPS_ARCH cuando se usa -r: el target x86_64-musl se
# queda con la arch del host (x86_64) y no resuelve ni sus propios paquetes
# ("not found in repository pool"). XBPS_ROOT si respeta la arch, asi que se
# traduce -r a XBPS_ROOT.
#
root=""
prev=""
for arg in "$@"; do
    if [ "$prev" = "-r" ]; then
        root="$arg"
    fi
    prev="$arg"
done

[ -n "$root" ] && export XBPS_ROOT="$root"

exec /usr/bin/xbps-install "$@"
