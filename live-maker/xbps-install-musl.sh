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

# Quita los repos de otra arch si el target no es musl.
case "${XBPS_ARCH:-}" in
    *-musl) ;;
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
