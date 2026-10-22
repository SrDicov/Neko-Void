#!/bin/sh
# flavor.sh: los manifests de flavors/ son la politica de cada flavor
# (que overlay, que kernel, que DM, que nombre de ISO, que paquetes extra).
#
#   sh flavor.sh <flavor> <clave>    -> el valor (hereda de base= si lo hay)
#   . ./flavor.sh ; flavor_get <flavor> <clave>
#
# ponytail: sin parser de YAML ni eval. El manifest es key=value plano y la
# jerarquia se resuelve con una llamada recursiva. Un flavor nuevo = un
# fichero; el builder, el --help y el CI leen el mismo sitio.

# FLAVOR_DIR: el que exporta el builder, o el que deduce de $0. Se fija
# explicitamente porque al sourcearlo $0 es del script que lo sourcea.
if [ -z "${FLAVOR_DIR:-}" ]; then
    FLAVOR_DIR="$(cd "$(dirname "$0")" && pwd)/flavors"
fi

# flavor_get <flavor> <clave> -> valor (vacio si no existe la clave)
# Devuelve 1 si el flavor no existe.
flavor_get() {
    _fg_flavor="$1"
    _fg_key="${2:-}"
    _fg_file="$FLAVOR_DIR/$_fg_flavor"
    [ -f "$_fg_file" ] || return 1

    # base= -> el padre aporta lo que el hijo no define.
    _fg_base=$(sed -n 's/^base=//p' "$_fg_file" | head -1)
    if [ -n "$_fg_base" ] && [ "$_fg_base" != "$_fg_flavor" ]; then
        _fg_val=$(flavor_get "$_fg_base" "$_fg_key") || _fg_val=""
    else
        _fg_val=""
    fi

    # El valor propio pisa al heredado.
    _fg_own=$(sed -n "s/^$_fg_key=//p" "$_fg_file" | head -1)
    [ -n "$_fg_own" ] && _fg_val="$_fg_own"

    printf '%s\n' "$_fg_val"
}

if [ "${0##*/}" = "flavor.sh" ]; then
    if [ $# -lt 2 ]; then
        echo "uso: flavor.sh <flavor> <clave>" >&2
        exit 2
    fi
    flavor_get "$1" "$2" || {
        echo "flavor desconocido: $1" >&2
        exit 1
    }
fi
