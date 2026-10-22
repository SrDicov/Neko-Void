#!/bin/sh
# test-wrapper.sh: el wrapper de xbps-install no debe filtrar los repos musl
# cuando el target es musl.
#
# ponytail: mklive hace dos llamadas distintas: install_packages (linea 159)
# pone XBPS_ARCH, pero la llamada -U de la linea 165 solo pone
# XBPS_TARGET_ARCH. Si el wrapper solo mirase XBPS_ARCH, la llamada -U
# creeria que el target es glibc, tiraria los repos musl y 'jq' (o
# cualquier paquete solo-musl) saldría como "not found in repository pool".

set -eu

cd "$(dirname "$0")/.."
WRAPPER="live-maker/xbps-install-musl.sh"
fake="$(mktemp -d)"
trap 'rm -rf "$fake"' EXIT

cat >"$fake/xbps-install" <<EOF
#!/bin/sh
printf '%s\n' "\$@"
EOF
chmod +x "$fake/xbps-install"

# Copia del wrapper con el exec apuntando al falso
sed "s|exec /usr/bin/xbps-install|exec $fake/xbps-install|" "$WRAPPER" >"$fake/wrapper"

fail=0
check() { # <descripcion> <esperado> <obtenido>
	if [ "$2" = "$3" ]; then
		echo "ok   $1"
	else
		echo "FALLO $1"
		echo "     esperado: $2"
		echo "     obtenido: $3"
		fail=$((fail + 1))
	fi
}

MUSC="--repository=https://repo-ci.voidlinux.org/current/musl"
GLIBC="--repository=https://repo-de.voidlinux.org/current"
AARCH="--repository=https://repo-de.voidlinux.org/current/aarch64"

# 1. install del target (XBPS_ARCH=musl): no se toca nada
out="$(XBPS_ARCH=x86_64-musl sh "$fake/wrapper" -r /t "$MUSC" "$GLIBC" "$AARCH" -yn jq)"
check "target musl (XBPS_ARCH) conserva los repos musl" \
	"3" "$(echo "$out" | grep -c -- '--repository=')"

# 2. llamada -U (solo XBPS_TARGET_ARCH): tampoco se toca nada
out="$(LANG=C XBPS_TARGET_ARCH=x86_64-musl sh "$fake/wrapper" -U -r /t "$MUSC" "$GLIBC" "$AARCH" -y jq)"
check "target musl (solo XBPS_TARGET_ARCH) conserva los repos musl" \
	"3" "$(echo "$out" | grep -c -- '--repository=')"

# 3. host glibc: se filtran musl y aarch64
out="$(XBPS_ARCH=x86_64 sh "$fake/wrapper" -r /h "$GLIBC" "$MUSC" "$AARCH" -y bash)"
check "host glibc filtra los repos musl" \
	"1" "$(echo "$out" | grep -c -- '--repository=')"
check "host glibc conserva el repo glibc" \
	"yes" "$(echo "$out" | grep -q -- "$GLIBC" && echo yes || echo no)"

# 4. sin variables: no se filtra (por si acaso, antes de romper)
out="$(sh "$fake/wrapper" "$MUSC" -y jq)"
check "sin variables no filtra" \
	"1" "$(echo "$out" | grep -c -- '--repository=')"

if [ "$fail" -ne 0 ]; then
	echo
	echo "$fail test(s) fallidos" >&2
	exit 1
fi
echo "Wrapper: ok"
