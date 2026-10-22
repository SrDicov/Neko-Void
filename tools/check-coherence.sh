#!/bin/sh
# check-coherence.sh: los manifests de flavors/, el builder, su --help y los
# workflows deben hablar de los mismos flavors y de rutas que existen.
#
# No construye nada: solo compara. Sale con 1 si algo no cuadra.
#
#   sh tools/check-coherence.sh
#
# ponytail: grep/sed/awk y nada mas. En el CI corre sin yq ni python: parsear
# YAML a mano con grep es mas barato que mantener un parser.

set -eu

cd "$(dirname "$0")/.."
BUILDER="live-maker/neko-builder.sh"
FLAVORS="live-maker/flavors"
PACKAGES="live-maker/base-neko-pkgs.sh"
WORKFLOWS=".github/workflows"
# ci/*.yml NO se comprueba: clona otro repo (codeberg) con otra nomenclatura.

errors=0
err() {
	echo "ERROR: $*" >&2
	errors=$((errors + 1))
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ── A. Flavors = los manifests ────────────────────────────────────────────
sh live-maker/flavor.sh --list 2>/dev/null | sort >"$tmp/flavors" || : >"$tmp/flavors"

if [ ! -s "$tmp/flavors" ]; then
	echo "ERROR: no hay ningun manifest en $FLAVORS" >&2
	exit 1
fi

# ── B. Dispatch externo del builder (aliases como 'doble') ───────────────
sed -n '/^case "\$DESKTOP" in/,$p' "$BUILDER" |
	sed -n 's/^ *\([a-z0-9_-]\+\))$/\1/p' | sort -u >"$tmp/dispatch"

cat "$tmp/flavors" "$tmp/dispatch" | sort -u >"$tmp/targets"

echo "flavors:   $(tr '\n' ' ' <"$tmp/flavors")"
echo "dispatch:  $(tr '\n' ' ' <"$tmp/dispatch")"
echo

# ── 1. Cada manifest tiene las claves obligatorias y son coherentes ───────
# Los valores se resuelven con flavor.sh (herencia base= incluida): el check
# usa el mismo lector que el builder y el CI.
fget() { sh live-maker/flavor.sh "$1" "$2" 2>/dev/null || true; }

for f in "$FLAVORS"/*; do
	[ -f "$f" ] || continue
	name="$(basename "$f")"
	for key in desc overlay packages kernel dm arch iso; do
		[ -n "$(fget "$name" "$key")" ] ||
			err "flavors/$name no define '$key'"
	done

	# El overlay tiene que existir en disco.
	ov="$(fget "$name" overlay)"
	[ -d "live-maker/$ov" ] ||
		err "flavors/$name usa el overlay 'live-maker/$ov' que no existe"

	# overlay2 (si lo hay) tambien.
	ov2="$(fget "$name" overlay2)"
	if [ -n "$ov2" ] && [ ! -d "live-maker/$ov2" ]; then
		err "flavors/$name usa el overlay2 'live-maker/$ov2' que no existe"
	fi

	# El set de paquetes tiene que existir en base-neko-pkgs.sh.
	pkg="$(fget "$name" packages)"
	[ -n "$pkg" ] && ! grep -q "^$pkg=" "$PACKAGES" &&
		err "flavors/$name pide el set '$pkg' que no define $PACKAGES"

	# base= tiene que apuntar a un flavor existente.
	base="$(sed -n 's/^base=//p' "$f")"
	if [ -n "$base" ] && [ ! -f "$FLAVORS/$base" ]; then
		err "flavors/$name hereda de 'base=$base' que no existe"
	fi
done

# ── 2. El builder solo puede construir flavors que existen ───────────────
for t in $(grep -oE 'build_iso +[a-z0-9_-]+' "$BUILDER" | awk '{print $2}' | sort -u); do
	grep -qx "$t" "$tmp/flavors" ||
		err "el builder llama a 'build_iso $t' pero no hay ningun manifest asi"
done

# ── 3. Los workflows solo pueden invocar flavors que existen ─────────────
for t in $(grep -hoE 'neko-builder\.sh +[a-z0-9_-]+' "$WORKFLOWS"/*.yml 2>/dev/null |
	awk '{print $2}' | sort -u); do
	grep -qx "$t" "$tmp/flavors" ||
		err "el CI invoca 'neko-builder.sh $t' pero no hay ningun manifest asi"
done

# ── 4. El --help tiene que listar exactamente los flavors ────────────────
# Quita los codigos de color: ESC real y la forma literal "\033" (que es lo
# que sale si el shell no expande \033 en las comillas del builder).
bash "$BUILDER" --help 2>/dev/null | sed 's/\\033//g' | tr -d '\033' |
	sed 's/\[[0-9;]*m//g' | awk '
	/^Flavors disponibles:/ { inf = 1; next }
	/^Opciones:/ { inf = 0 }
	/^Especiales:/ { esp = 1; next }
	inf && /^  [a-z0-9_-]+ +/ { print $1 }
	esp && /^  [a-z0-9_-]+ +/ { print $1 }
' | sort -u >"$tmp/help"
while read -r t; do
	[ -n "$t" ] || continue
	grep -qx "$t" "$tmp/help" ||
		err "el --help no anuncia el flavor '$t'"
done <"$tmp/targets"
while read -r t; do
	[ -n "$t" ] || continue
	grep -qx "$t" "$tmp/targets" ||
		err "el --help anuncia '$t' pero no hay ningun flavor ni alias asi"
done <"$tmp/help"

# ── 5. La matrix del CI tiene que ser la lista de flavors ────────────────
awk '
	/^      iso:/ { iniso = 1; next }
	/^      [a-z_]+:/ { iniso = 0 }
	iniso && /^          - / { sub(/^          - /, ""); print }
' "$WORKFLOWS/build-iso.yml" | grep -v '^all$' | sort >"$tmp/matrix"

if ! diff -u "$tmp/flavors" "$tmp/matrix" >"$tmp/matrix.diff" 2>&1; then
	err "la lista de flavors del input 'iso' no coincide con $FLAVORS:" &&
		sed 's/^/    /' "$tmp/matrix.diff" >&2
fi

# ── 6. Las ramas del case del workflow tienen que ser flavors ───────────
# Solo el case de "$DESKTOP": otros cases (p.ej. por arch) no son flavors.
awk '
	/case "\$DESKTOP" in/ { inc = 1; next }
	inc && /^          esac/ { inc = 0 }
	inc && /^            [a-z0-9*_|-]+\)$/ { print }
' "$WORKFLOWS/build-iso.yml" >"$tmp/branches"
while read -r branch; do
	[ -n "$branch" ] || continue
	for one in $(echo "$branch" | tr -d ')' | tr '|' ' '); do
		one="$(echo "$one" | tr -d '*')"
		[ -n "$one" ] || continue
		grep -qx "$one" "$tmp/flavors" ||
			err "el workflow tiene una rama para '$one' que no es un flavor"
	done
done <"$tmp/branches"

# ── 7. La lista de repos no puede mezclar glibc y musl ───────────────────
# Un repo musl no tiene x86_64-repodata: xbps lo busca igual al sincronizar
# y aborta con "[reposync] failed to fetch ... Not Found".
awk '
	/-musl \]\]; then/ { mode = "musl"; next }
	/^[[:space:]]*else[[:space:]]*$/ && mode == "musl" { mode = "glibc"; next }
	/^[[:space:]]*fi[[:space:]]*$/ { mode = ""; next }
	mode == "glibc" && /-r https/ && /musl/ { print }
' "$BUILDER" >"$tmp/bad_repos"
if [ -s "$tmp/bad_repos" ]; then
	err "la lista glibc de repos incluye repos musl (xbps aborta al sincronizar):"
	sed 's/^/    /' "$tmp/bad_repos" >&2
fi

# ── 8. Las rutas de overlay que citan los workflows tienen que existir ───
grep -hoE '[a-z0-9_-]+/(etc|home|usr|var)/' "$WORKFLOWS"/*.yml 2>/dev/null |
	sed 's|/.*||' | sort -u >"$tmp/wpaths"
while read -r d; do
	[ -n "$d" ] || continue
	[ "$d" = "usr" ] && continue
	[ -d "live-maker/$d" ] ||
		err "los workflows usan '$d/...' pero 'live-maker/$d' no existe"
done <"$tmp/wpaths"

# ── 9. La arch declarada tiene que ser una que el builder pueda hacer ───
# Los flavors de Neko son x86_64: sus overlays, el bootloader y los repos son
# x86_64. Las demas arches se construyen con el toolkit upstream de
# void-mklive (que se comprueba mas abajo), no con estos flavors.
for f in "$FLAVORS"/*; do
	[ -f "$f" ] || continue
	name="$(basename "$f")"
	arch="$(fget "$name" arch)"
	case "$arch" in
		x86_64|x86_64-musl) ;;
		*) err "flavors/$name declara arch=$arch; el builder de Neko solo hace x86_64 y x86_64-musl" ;;
	esac
done

# ── 10. El toolkit multi-arch de upstream tiene que seguir intacto ──────
# Es el camino para aarch64/armv7l/armv6l/i686 (lib.sh:279 mapea platform ->
# arch). El plan original pedia borrar el Makefile: no se borra.
for f in Makefile lib.sh mkrootfs.sh mkplatformfs.sh mkimage.sh mknet.sh; do
	[ -f "live-maker/$f" ] ||
		err "falta live-maker/$f (toolkit multi-arch de upstream void-mklive)"
done
[ -d "live-maker/platforms" ] ||
	err "falta live-maker/platforms (definiciones de plataformas upstream)"
grep -q "aarch64" live-maker/lib.sh ||
	err "live-maker/lib.sh ya no mapea aarch64: el camino multi-arch se ha roto"

if [ "$errors" -ne 0 ]; then
	echo
	echo "$errors incoherencia(s). Arregla los manifests, el builder o los workflows." >&2
	exit 1
fi
echo "Coherente: manifests, builder, --help y workflows hablan de los mismos flavors."
