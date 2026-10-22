#!/bin/bash
#
# Wrapper de xbps-install para mklive.
#
# xbps >= 0.60 ignora XBPS_ARCH cuando se usa -r: el target x86_64-musl se
# queda con la arch del host (x86_64) y no resuelve ni sus propios paquetes
# ("not found in repository pool"). XBPS_ROOT si respeta la arch, asi que se
# traduce -r a XBPS_ROOT.
#
# ponytail: mklive.sh anade siempre los repos musl y aarch64
# (mklive.sh:554). Para un target glibc esos repos no tienen
# x86_64-repodata, asi que xbps los sincroniza y falla con "[reposync]
# failed to fetch ... Not Found" (reintenta y ralentiza). Para un target
# musl hacen falta, asi que solo se quitan cuando la arch no es musl.
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

# Las claves de confianza del overlay (var/db/xbps/keys) tienen que estar en el
# keyring del TARGET: con -r, xbps lee el keyring del root, no el del sistema,
# y la importacion interactiva de la clave puede fallar ("Failed to import
# pubkey ... Resource temporarily unavailable"). Sin esto, los paquetes de un
# repo firmador salen con "the RSA signature is not valid" y la transaccion
# aborta entera. El nombre del fichero es la huella, que es como xbps las lee.
if [ -n "${NEKO_TRUST_KEYS:-}" ] && [ -n "$root" ]; then
    mkdir -p "$root/var/db/xbps/keys"
    cp -f "$NEKO_TRUST_KEYS"/*.plist "$root/var/db/xbps/keys/" 2>/dev/null || true
fi

# Quita los repos de otra arch si el target no es musl.
# ponytail: mklive usa las dos variables segun la llamada: install_packages
# pone XBPS_ARCH (linea 159) pero la llamada -U de la linea 165 solo pone
# XBPS_TARGET_ARCH. Hay que mirar las dos: si solo se mirase XBPS_ARCH, la
# llamada -U creeria que el target es glibc, filtraria los repos musl y
# 'jq' (o cualquier paquete solo-musl) saldría como "not found in repository
# pool".
_neko_arch="${XBPS_ARCH:-${XBPS_TARGET_ARCH:-}}"
case "$_neko_arch" in
    "") ;;   # arch desconocida: no filtrar (fail-safe, un repo de mas no rompe)
    *-musl) ;;   # target musl: los repos musl hacen falta
    *)
        args=()
        skip=0
        for arg in "$@"; do
            if [ "$skip" = 1 ]; then
                # valor de "--repository URL" (forma con espacio)
                skip=0
                continue
            fi
            case "$arg" in
                --repository=*musl*|--repository=*aarch64*)
                    ;;
                --repository)
                    skip=1
                    ;;
                *)
                    args+=("$arg")
                    ;;
            esac
        done
        set -- "${args[@]}"
        ;;
esac

exec /usr/bin/xbps-install "$@"
