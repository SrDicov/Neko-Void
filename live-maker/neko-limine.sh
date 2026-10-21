#!/bin/bash
#
# NekoVoid Live ISO Builder — variante Limine (BIOS + UEFI)
#
# mklive.sh se encarga del rootfs, initramfs y squashfs; este script conserva
# ese árbol (-K) y remasteriza la ISO con Limine en lugar de GRUB+isolinux:
#
#   BIOS : limine-bios-cd.bin (El Torito no-emul-boot) + limine-bios.sys
#   UEFI : limine-uefi-cd.bin (El Torito EFI) + EFI/BOOT/BOOTX64.EFI
#   USB  : `limine bios-install` escribe el MBR de Limine (arranque híbrido)
#
# El kernel, el initrd y la línea de comandos se toman del árbol que genera
# mklive.sh, así que la ISO de Limine y la de GRUB arrancan exactamente igual.
#
# Uso: sudo ./neko-limine.sh [opciones de mklive.sh ...]

set -euo pipefail
# ponytail: libisofs convierte los nombres con el charset del locale; sin un
# locale UTF-8 busca un charmap externo que Void no empaqueta y falla con
# "Charset conversion error". void-mklive traia LANG=en_US.UTF-8; void-glibc no.
export LANG="${LANG:-C.UTF-8}"

cd "$(dirname "$(readlink -f "$0")")"

# Repo y arquitectura del host donde está el paquete `limine` con sus binarios.
# El host puede ser glibc o musl: el repo y la arch deben encajar con su libc.
# (mklive deja XBPS_ARCH=x86_64-musl en el entorno, y sin corregirlo el host
#  buscaria el paquete para musl en un repo glibc: "not found in repository pool")
if ldd --version 2>&1 | head -1 | grep -qi musl; then
    LIMINE_REPO="${LIMINE_REPO:-https://repo-de.voidlinux.org/current/musl}"
    LIMINE_ARCH="x86_64-musl"
else
    LIMINE_REPO="${LIMINE_REPO:-https://repo-de.voidlinux.org/current}"
    LIMINE_ARCH="x86_64"
fi
LIMINE_DATADIR="${LIMINE_DATADIR:-/usr/share/limine}"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# ─── Opciones: -o y -K los gestionamos aquí, el resto va a mklive.sh ───
OUTPUT=""
ISO_TITLE="NekoVoid"
KEEP_BUILDDIR=no
MKLIVE_ARGS=()
args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
        -o)
            OUTPUT="${args[$((i+1))]}"
            i=$((i+2))
            ;;
        -T)
            ISO_TITLE="${args[$((i+1))]}"
            MKLIVE_ARGS+=("${args[$i]}" "${args[$((i+1))]}")
            i=$((i+2))
            ;;
        -K)
            KEEP_BUILDDIR=yes
            i=$((i+1))
            ;;
        *)
            MKLIVE_ARGS+=("${args[$i]}")
            i=$((i+1))
            ;;
    esac
done

[ "$(id -u)" -eq 0 ] || die "Debe ejecutarse como root (sudo)"
[ -x ./mklive.sh ] || die "mklive.sh no encontrado en $(pwd)"

WORKDIR="$(mktemp -d -t neko-limine.XXXXXX)"
cleanup() {
    if [ "$KEEP_BUILDDIR" = no ]; then
        rm -rf "$WORKDIR"
    else
        echo "Build conservado en: $WORKDIR"
    fi
    [ -n "$LIMINE_ROOT" ] && rm -rf "$LIMINE_ROOT"
    return 0
}
trap cleanup EXIT

# ─── 1. mklive.sh genera rootfs, initramfs, squashfs e ISO con GRUB ───
# ROOTDIR fija dónde mklive deja el árbol de la imagen; -K lo conserva.
info "Generando la imagen con mklive.sh (árbol conservado para remasterizar)..."
mkdir -p "$WORKDIR/build"
ROOTDIR="$WORKDIR/build" ./mklive.sh -K -o "$WORKDIR/mklive.iso" "${MKLIVE_ARGS[@]}"

BUILDDIR="$(echo "$WORKDIR"/build/mklive-build.*)"
[ -d "$BUILDDIR/image" ] || die "No se encontró el árbol de la imagen en $BUILDDIR"
IMAGEDIR="$BUILDDIR/image"
VOIDHOSTDIR="$BUILDDIR/void-host"

# La ISO con GRUB ya no hace falta: el contenido está en el árbol.
rm -f "$WORKDIR/mklive.iso"

# ─── 2. Datos de arranque tomados de la config que generó mklive.sh ───
GRUBCFG="$IMAGEDIR/boot/grub/grub_void.cfg"
[ -f "$GRUBCFG" ] || die "No se encontró $GRUBCFG"

# Título de la primera entrada ("NekoVoid 6.x (x86_64)") y línea de comandos
# del kernel: son los mismos que usa GRUB, así no puede haber divergencia.
ENTRY_TITLE="$(awk '/^[[:space:]]*menuentry "/ { sub(/^[^"]*"/, ""); sub(/".*$/, ""); print; exit }' "$GRUBCFG")"
CMDLINE="$(awk '
    /^[[:space:]]*linux \(/ { grab = 1; next }
    grab && /^[[:space:]]*initrd / { exit }
    grab { line = $0; sub(/[[:space:]]*\\[[:space:]]*$/, "", line); sub(/^[[:space:]]+/, "", line); print line }
' "$GRUBCFG" | tr '\n' ' ' | sed -e 's/[[:space:]]\+/ /g' -e 's/^ //' -e 's/ $//')"

[ -n "$ENTRY_TITLE" ] || die "No se pudo leer el título de las entradas de GRUB"
[ -n "$CMDLINE" ] || die "No se pudo leer la línea de comandos del kernel de GRUB"

# El volumen de la ISO debe coincidir con CDLABEL= de la línea de comandos.
VOLID="$(sed -n 's/.*CDLABEL=\([^ ]*\).*/\1/p' <<< "$CMDLINE")"
[ -n "$VOLID" ] || die "La línea de comandos no contiene CDLABEL=: $CMDLINE"

if [ -f "$IMAGEDIR/boot/vmlinuz" ]; then
    KERNEL_IMG="vmlinuz"
elif [ -f "$IMAGEDIR/boot/vmlinux" ]; then
    KERNEL_IMG="vmlinux"
else
    die "No se encontró el kernel en $IMAGEDIR/boot"
fi

# ─── 3. Paquete limine (binarios EFI/BIOS + herramienta bios-install) ───
# Repo explicito + arch del host: mklive deja XBPS_ARCH=x86_64-musl en el
# entorno y la imagen de Void glibc no trae repos en /etc/xbps.d, asi que
# sin --repository el pool de xbps esta vacio.
# Cache propia: el cachedir de xbps es del runner y xbps no puede cambiar los
# permisos de esos ficheros (EPERM al instalar).
LIMINE_ROOT=""
LIMINE_CMD=(limine)
if [ ! -f "$LIMINE_DATADIR/limine-bios-cd.bin" ]; then
    info "Instalando el paquete limine..."
    LIMINE_ROOT="$(mktemp -d)"
    XBPS_ARCH="$LIMINE_ARCH" XBPS_CACHE_DIR="$LIMINE_ROOT/cache" \
        xbps-install -y --repository="$LIMINE_REPO" limine ||
        XBPS_ARCH="$LIMINE_ARCH" XBPS_CACHE_DIR="$LIMINE_ROOT/cache" \
            xbps-install -y limine ||
        die "No se pudo instalar limine desde $LIMINE_REPO"
fi
[ -x /usr/bin/limine ] || die "No se encontró /usr/bin/limine"

# ─── 4. Árbol de arranque de Limine dentro de la ISO ───
info "Preparando el árbol de arranque de Limine..."
rm -rf "$IMAGEDIR/boot/grub" "$IMAGEDIR/boot/isolinux"

mkdir -p "$IMAGEDIR/EFI/BOOT"
cp -f "$LIMINE_DATADIR/limine-bios-cd.bin" "$IMAGEDIR/"
cp -f "$LIMINE_DATADIR/limine-uefi-cd.bin" "$IMAGEDIR/"
cp -f "$LIMINE_DATADIR/limine-bios.sys" "$IMAGEDIR/"
cp -f "$LIMINE_DATADIR/BOOTX64.EFI" "$IMAGEDIR/EFI/BOOT/BOOTX64.EFI"
[ -f "$LIMINE_DATADIR/BOOTIA32.EFI" ] && cp -f "$LIMINE_DATADIR/BOOTIA32.EFI" "$IMAGEDIR/EFI/BOOT/"
[ -f "$LIMINE_DATADIR/BOOTAA64.EFI" ] && cp -f "$LIMINE_DATADIR/BOOTAA64.EFI" "$IMAGEDIR/EFI/BOOT/"

# El splash que usa GRUB/isolinux como wallpaper del menú de Limine.
[ -f data/splash.png ] && cp -f data/splash.png "$IMAGEDIR/boot/splash.png"

# Shell UEFI (tecla U en el menú de Limine): permite arrancar a mano Windows
# u otro SO desde la ESP. Opcional: si el paquete no está, se sigue sin él.
if [ ! -f /usr/share/edk2/x64/Shell_Full.efi ]; then
    XBPS_ARCH="$LIMINE_ARCH" XBPS_CACHE_DIR="${LIMINE_ROOT:-/tmp}/cache" \
        xbps-install -y --repository="$LIMINE_REPO" edk2-shell >/dev/null 2>&1 || true
fi
[ -f /usr/share/edk2/x64/Shell_Full.efi ] && cp -f /usr/share/edk2/x64/Shell_Full.efi "$IMAGEDIR/shellx64.efi"

# ─── 5. limine.conf ───
info "Generando limine.conf..."
sed -e "s|@@ISO_TITLE@@|$ISO_TITLE|g" \
    -e "s|@@ENTRY_TITLE@@|$ENTRY_TITLE|g" \
    -e "s|@@KERNEL_IMG@@|$KERNEL_IMG|g" \
    -e "s|@@CMDLINE@@|$CMDLINE|g" \
    limine/limine.cfg.in > "$IMAGEDIR/limine.conf"

# ─── 6. Remasterizar la ISO con Limine (BIOS + UEFI + híbrido USB) ───
[ -n "$OUTPUT" ] || OUTPUT="nekovoid-limine-$(date -u +%Y%m%d).iso"

XORRISO="xorriso"
[ -x "$VOIDHOSTDIR/usr/bin/xorriso" ] && XORRISO="$VOIDHOSTDIR/usr/bin/xorriso"

info "Remasterizando la ISO con Limine..."
# ponytail: sin -input-charset, libisofs usa su tabla interna y no busca un
# charmap externo (Void no empaqueta /usr/share/libisoburn). Sin -hfsplus:
# el volumen HFS+ no lo usa nadie aqui y rompe el remasterizado con glibc
# 2.41 ("Charset conversion error").
"$XORRISO" -as mkisofs \
    -iso-level 3 -rock -joliet -joliet-long -max-iso9660-filenames \
    -omit-period -omit-version-number -relaxed-filenames -allow-lowercase \
    -volid "$VOLID" \
    -b limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
    -apm-block-size 2048 --efi-boot limine-uefi-cd.bin \
    -efi-boot-part --efi-boot-image --protective-msdos-label \
    -output "$OUTPUT" "$IMAGEDIR" || die "xorriso falló"

# ─── 7. Híbrido: la ISO también arranca como disco (USB) en BIOS ───
info "Instalando el MBR de Limine (arranque híbrido USB)..."
"${LIMINE_CMD[@]}" bios-install "$OUTPUT" || die "limine bios-install falló"

info "ISO con Limine creada: $(readlink -f "$OUTPUT") ($(stat -c '%s' "$OUTPUT") bytes)"
