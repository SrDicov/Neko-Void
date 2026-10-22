#!/bin/bash
#
# NekoVoid Live ISO Builder - Nonfree Edition
# Genera la ISO con soporte nonfree: Steam, gaming, drivers propietarios, etc.
#
# Uso:
#   ./neko-builder.sh                        # Modo interactivo
#   ./neko-builder.sh <desktop>              # Construir escritorio específico
#   ./neko-builder.sh <desktop> -e "pkg..."  # Con paquetes extra
#   ./neko-builder.sh doble                  # Construir xlibre + xorg
#   ./neko-builder.sh doble-isor             # Construir rollibre + rolling
#
VERSION=$(date +"%Y%m%d")
set -euo pipefail
# ponytail: libisofs convierte los nombres con el charset del locale; sin un
# locale UTF-8 busca un charmap externo que Void no empaqueta y el ISO falla.
export LANG="${LANG:-C.UTF-8}"
# ponytail: mklive usa xbps-install con -r, y xbps >= 0.60 ignora XBPS_ARCH
# con -r: el target musl no resuelve sus paquetes. El wrapper pasa XBPS_ROOT.
export XBPS_INSTALL_CMD="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/xbps-install-musl.sh"
# Overlay temporal del instalador (lo crea build_iso); se borra al salir.
INSTALL_OVERLAY=""
cleanup() { [ -n "$INSTALL_OVERLAY" ] && rm -rf "$INSTALL_OVERLAY"; return 0; }
trap cleanup EXIT
KERNEL_DEFAULT="linux-mainline"
KERNEL_STABLE="linux6.18"
# ─────────────────────────────────────────────
# Configuración de salida
# ─────────────────────────────────────────────

ISO_TITLE="NekoVoid"

# ─────────────────────────────────────────────
# Driver NVIDIA (descomentar si tienes GPU NVIDIA)
# Debe definirse antes de cargar base-neko-pkgs.sh
# porque DEFAULT lo referencia.
# ─────────────────────────────────────────────
NVIDIA="${NVIDIA:-}"

# ─────────────────────────────────────────────
# Cargar definiciones de paquetes
# ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

. ./base-neko-pkgs.sh
# Politica de cada flavor: los manifests de flavors/ (overlay, kernel, DM,
# nombre de ISO, paquetes extra). El builder, el --help y el CI leen aqui.
FLAVOR_DIR="$SCRIPT_DIR/flavors"
. ./flavor.sh

# ─────────────────────────────────────────────
# Servicios base (el display manager se agrega
# automáticamente según el escritorio)
# ─────────────────────────────────────────────
SERVICES_BASE="dbus NetworkManager polkitd rtkit sshd chronyd zramen tlp tlp-pd"

# ─────────────────────────────────────────────
# Colores para modo interactivo
# ─────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# ─────────────────────────────────────────────
# usage() – Ayuda
# ─────────────────────────────────────────────
usage() {
    cat <<EOF
${BOLD}NekoVoid Live ISO Builder${RESET}

Uso: $(basename "$0") [FLAVOR] [OPCIONES]
      $(basename "$0")                          ${CYAN}# Modo interactivo${RESET}

Flavors disponibles:
EOF
    local f name desc
    for f in flavors/*; do
        [ -f "$f" ] || continue
        name="$(basename "$f")"
        desc="$(flavor_get "$name" desc)"
        printf "  ${GREEN}%-14s${RESET} %s\n" "$name" "$desc"
    done
    cat <<EOF

Especiales:
  ${GREEN}doble${RESET}       Construye matelibre + mate (Xlibre y Xorg)

Opciones:
  -e, --extra "pkg1 pkg2"   Agregar paquetes extra a la ISO
  -b, --bootloader "grub|limine"
                            Bootloader de la ISO (por defecto: grub)
                            grub   = GRUB (UEFI) + isolinux (BIOS), como siempre
                            limine = Limine para BIOS y UEFI (dualboot)
  -h, --help                Mostrar esta ayuda

Ejemplos:
  $(basename "$0")                        # Menú interactivo
  $(basename "$0") icewm                  # Construir IceWM directamente
  $(basename "$0") kde -e "gimp inkscape" # KDE + paquetes extra
  $(basename "$0") labwc -b limine        # Labwc con Limine (BIOS+UEFI)
EOF
}

# ─────────────────────────────────────────────
# build_iso() – Construye una ISO para un
#               escritorio específico
#
# Argumentos:
#   $1 = clave del escritorio
#   $2 = paquetes extra (opcional)
# ─────────────────────────────────────────────
build_iso() {
    local desktop="$1"
    local extra_pkgs="${2:-}"

    # ─── Politica del flavor: todo sale de flavors/<nombre> ───
    if [ ! -f "flavors/$desktop" ]; then
        echo -e "${BOLD}Error:${RESET} Flavor desconocido '${desktop}'"
        echo "Usa --help para ver los flavors disponibles."
        exit 1
    fi

    local desc overlay overlay2 packages kernel dm arch iso_prefix postsetup
    desc="$(flavor_get "$desktop" desc)"
    overlay="$(flavor_get "$desktop" overlay)"
    overlay2="$(flavor_get "$desktop" overlay2)"
    packages="$(flavor_get "$desktop" packages)"
    kernel="$(flavor_get "$desktop" kernel)"
    dm="$(flavor_get "$desktop" dm)"
    arch="$(flavor_get "$desktop" arch)"
    iso_prefix="$(flavor_get "$desktop" iso)"
    postsetup="$(flavor_get "$desktop" postsetup)"

    if [ -z "$packages" ]; then
        echo -e "${BOLD}Error:${RESET} flavors/$desktop no define 'packages'"
        exit 1
    fi

    # El manifest da el NOMBRE del set de paquetes; aqui se expande.
    local pkg_list="${!packages}"
    # extra= del manifest (variantes nvidia) + extra de la linea de comandos.
    local manifest_extra="$(flavor_get "$desktop" extra)"
    if [ -n "$manifest_extra" ]; then
        pkg_list="$pkg_list $manifest_extra"
    fi
    if [ -n "$extra_pkgs" ]; then
        pkg_list="$pkg_list $extra_pkgs"
    fi
    # Los flavors con postsetup de NVIDIA necesitan las cabeceras del kernel.
    if [ -n "$postsetup" ]; then
        pkg_list="$pkg_list linux6.18-headers"
    fi

    local includedir="./$overlay"
    local includedir2=""
    [ -n "$overlay2" ] && includedir2="./$overlay2"
    local iso_name="${iso_prefix}-${VERSION}.iso"

    # ─── Bootloader Limine: ISO propia + paquete limine dentro del live ───
    # (el paquete sirve para instalar Limine a mano en el disco y encadenar
    #  Windows/Linux: `limine bios-install /dev/sdX`)
    if [ "$BOOTLOADER" = limine ]; then
        iso_name="${iso_name%.iso}-limine.iso"
        pkg_list="$pkg_list limine"
    fi

    # ─── Banner informativo ───
    echo ""
    echo "============================================="
    echo "  NekoVoid Live ISO Builder (Nonfree)"
    echo "============================================="
    echo ""
    echo "  Flavor:          ${desktop} (${desc})"
    echo "  ISO de salida:   ${iso_name}"
    echo "  Bootloader:      ${BOOTLOADER}"
    echo "  Paquetes total:  $(echo "${pkg_list}" | wc -w)"
    if [ -n "$kernel" ]; then
        echo "  Kernel:          ${kernel}"
    else
        echo "  Kernel:          (por defecto)"
    fi
    if [ -n "$extra_pkgs" ]; then
        echo "  Paquetes extra:  ${extra_pkgs}"
    fi
    echo ""

    # ─── Construir comando ───
    local cmd_args=(
        -a "$arch"
        -I "$includedir"
    )
    # ponytail: mklive.sh copia TODOS los -I al ROOTFS; el ultimo pisa solo los
    # ficheros que compiten por la misma ruta. labwc-musl usa el segundo.
    if [ -n "$includedir2" ]; then
        cmd_args+=(-I "$includedir2")
    fi
    # ─── Instalador: fuente única (live-maker/installer.sh) ───
    # mklive.sh no instala el instalador (solo lo hace mkiso.sh, que el builder
    # no usa), asi que se materializa aqui en un overlay temporal. Antes cada
    # overlay traia su propia copia y pisaba la de mkiso: 10 forks divergentes
    # del upstream y el @@MKLIVE_VERSION@@ sin sustituir.
    INSTALL_OVERLAY="$(mktemp -d -t neko-installer.XXXXXX)"
    mkdir -p "$INSTALL_OVERLAY/usr/bin"
    sed "s/@@MKLIVE_VERSION@@/$(cat version)/g" installer.sh \
        > "$INSTALL_OVERLAY/usr/bin/void-installer"
    chmod 755 "$INSTALL_OVERLAY/usr/bin/void-installer"
    cmd_args+=(-I "$INSTALL_OVERLAY")
    cmd_args+=(
        -o "$iso_name"
        -T "$ISO_TITLE"
        -p "$pkg_list"
    )

    if [ -n "$postsetup" ]; then
        if [ ! -f "$postsetup" ] || [ ! -x "$postsetup" ]; then
            echo -e "${BOLD}Error:${RESET} Postsetup script no encontrado o no ejecutable: $postsetup"
            exit 1
        fi
    fi

    if [ -n "$kernel" ]; then
        cmd_args+=(-v "$kernel")
    fi

    if [ -n "$postsetup" ]; then
        cmd_args+=(-x "$postsetup")
    fi

    cmd_args+=(-S "$SERVICES_BASE $dm")

    # ponytail: repos glibc y musl no se mezclan. musl usa repo-ci (mirror de CI
    # upstream, consistente) + z-repo-musl. El repo de sourceforge queda fuera:
    # sirve versiones viejas (neko-themes 6.5_1) firmadas con otra clave y xbps
    # aborta al no poder verificarlas.
    if [[ "$arch" == *-musl ]]; then
        REPOS=(
            -r https://repo-ci.voidlinux.org/current/musl
            -r https://repo-ci.voidlinux.org/current/musl/nonfree
            -r https://github.com/SrDicov/z-repo-musl/releases/download/stable
        )
    else
        REPOS=(
            -r https://github.com/xlibre-void/xlibre/releases/latest/download
            -r https://github.com/Neko-Void-Linux/repo-neko/releases/download/stable
            -r https://repo-de.voidlinux.org/current/nonfree
            -r https://repo-de.voidlinux.org/current
            -r https://repo-de.voidlinux.org/current/multilib/nonfree
            -r https://repo-de.voidlinux.org/current/multilib
            -r https://repo-de.voidlinux.org/current/musl/bootstrap
            -r https://repo-de.voidlinux.org/current/musl
            -r https://repo-de.voidlinux.org/current/musl/nonfree
            -r https://sourceforge.net/projects/neko-void/files/repo/musl
        )
    fi

    # ponytail: zstd -L 22 tarda ~7 min en el squashfs de 2 GB y solo ahorra un
    # 5% de tamaño frente a -L 19. Para "isos actualizadas lo mas rapido
    # posible", -L 19 es el punto: 2,5x menos tiempo de CPU.
    if [ "$BOOTLOADER" = limine ]; then
        sudo ./neko-limine.sh "${REPOS[@]}" -i xz -s zstd -L 19 "${cmd_args[@]}"
    else
        sudo ./mklive.sh "${REPOS[@]}" -i xz -s zstd -L 19 "${cmd_args[@]}"
    fi
    # ponytail: la ISO la crea root (sudo) y el builder puede correr como otro
    # usuario; la redireccion la hace el shell, asi que va dentro de sudo.
    sudo sh -c "sha256sum '$iso_name' > '$iso_name.txt'"
}

# ─────────────────────────────────────────────
# interactive_menu() – Menú interactivo cuando
#                       no se pasan argumentos
# ─────────────────────────────────────────────
interactive_menu() {
    echo ""
    echo -e "${BOLD}=============================================${RESET}"
    echo -e "${BOLD}  NekoVoid Live ISO Builder – Interactivo${RESET}"
    echo -e "${BOLD}=============================================${RESET}"
    echo ""
    echo -e "  ${CYAN}Flavors disponibles:${RESET}"
    echo ""

    # La lista sale de flavors/: no puede desincronizarse con el builder.
    local -a flavor_list=()
    local f name total=0
    for f in flavors/*; do
        [ -f "$f" ] || continue
        name="$(basename "$f")"
        total=$((total + 1))
        flavor_list+=("$name")
        echo -e "  ${GREEN}$total)${RESET} ${name}  ${YELLOW}→${RESET} $(flavor_get "$name" desc)"
    done

    echo ""
    local choice
    read -r -p "  Selecciona flavor [1-$total]: " choice

    if ! printf '%s' "$choice" | grep -qE '^[0-9]+$' ||
        [ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ]; then
        echo -e "${BOLD}Error:${RESET} Opción inválida '$choice'."
        exit 1
    fi

    echo ""
    read -r -p "  ¿Agregar paquetes extra? (nombres separados por espacio, Enter para omitir): " extra_pkgs

    build_iso "${flavor_list[$((choice - 1))]}" "$extra_pkgs"
}

# ─────────────────────────────────────────────
# MAIN – Parseo de argumentos
# ─────────────────────────────────────────────
EXTRA_PKGS=""
DESKTOP=""
BOOTLOADER="${NEKO_BOOTLOADER:-grub}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -e|--extra)
            if [ $# -lt 2 ]; then
                echo "Error: -e/--extra requiere un argumento (ej: -e \"gimp inkscape\")"
                exit 1
            fi
            EXTRA_PKGS="$2"
            shift 2
            ;;
        -b|--bootloader)
            if [ $# -lt 2 ]; then
                echo "Error: -b/--bootloader requiere un argumento (grub|limine)"
                exit 1
            fi
            case "$2" in
                grub|limine) BOOTLOADER="$2" ;;
                *) echo "Error: bootloader inválido '$2' (usa grub o limine)"; exit 1 ;;
            esac
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Error: Opción desconocida '$1'. Usa --help para ayuda."
            exit 1
            ;;
        *)
            if [ -z "$DESKTOP" ]; then
                DESKTOP="$1"
            else
                echo "Error: Ya se especificó el escritorio '$DESKTOP'. No se puede usar '$1' también."
                echo "Usa --help para ver la sintaxis."
                exit 1
            fi
            shift
            ;;
    esac
done

# ─── Si no hay escritorio especificado → modo interactivo ───
case "$BOOTLOADER" in
    grub|limine) ;;
    *) echo "Error: bootloader inválido '$BOOTLOADER' (usa grub o limine)"; exit 1 ;;
esac

if [ -z "$DESKTOP" ]; then
    interactive_menu
    exit 0
fi

# ─── Despachar según el flavor ───
case "$DESKTOP" in
    doble)
        echo -e "${CYAN}→ Construyendo matelibre + mate...${RESET}"
        build_iso matelibre "$EXTRA_PKGS"
        echo ""
        build_iso mate "$EXTRA_PKGS"
        ;;
    *)
        build_iso "$DESKTOP" "$EXTRA_PKGS"
        ;;
esac
