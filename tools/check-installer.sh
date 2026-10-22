#!/bin/sh
# check-installer.sh: cada comando que ESCRIBE en el disco del target tiene
# que comprobar su exit code, con el patron que ya usa upstream:
#     if [ $? -ne 0 ]; then DIALOG --msgbox "..."; DIE 1; fi
#
# ponytail: installer.sh NO lleva 'set -e' a proposito. Upstream usa el codigo
# de salida de dialog (1 = Cancelar) y de grep (1 = sin coincidencia) como
# control de flujo: con errexit+pipefail el instalador muere en la primera
# get_option de una opcion todavia no puesta, o al pulsar 'Atras' en un menu
# (probado en tools/README o en el commit que lo motivo). Este lint es la
# cobertura MECANICA: hoy y los comandos que se anadan manana.
#
# Salida 1 si hay un comando destructivo sin comprobar.

set -eu

cd "$(dirname "$0")/.."
INSTALLER="live-maker/installer.sh"

[ -f "$INSTALLER" ] || { echo "ERROR: no existe $INSTALLER" >&2; exit 1; }

errors=0
warns=0

# Comandos que tocan el disco del target de forma destructiva.
# Anclados al principio de la linea: asi no casan con las definiciones de
# funcion (mount_filesystems() {), los mensajes del dialogo ("failed to
# mount...") ni las llamadas a los wrappers.
destructive='^[[:space:]]*(chroot|mount|umount|mkswap|swapon|mkfs\.[a-z0-9]+|mke2fs|wipefs|dd|parted|sfdisk)([[:space:]]|$)'

# Copias de ficheros al target: si fallan, falta un config (no se pierde disco).
copies='^[[:space:]]*cp([[:space:]]+-[a-zA-Z]+)*[[:space:]].*\$?\{?TARGETDIR'

# Un check de exit code: 'if [ $? -ne 0 ]', 'rv=$?', '|| DIE', '&& DIE'.
is_check() {
	grep -qE '\-ne 0|rv=\$\?|\|\| *DIE|&& *DIE|if +!' || return 1
	return 0
}

audit() { # <patron> <nivel: error|warn|info>
	pattern="$1"
	level="$2"
	lineno=0
	while IFS= read -r line; do
		lineno=$((lineno + 1))
		case "$line" in
			*'#'*) continue ;;   # comentario
			*[a-zA-Z_]*'() {'*) continue ;;   # definicion de funcion
		esac
		echo "$line" | grep -qE "$pattern" || continue
		# ¿esta el check en las 4 lineas siguientes?
		found=no
		n=1
		while [ "$n" -le 4 ]; do
			if sed -n "$((lineno + n))p" "$INSTALLER" | is_check; then
				found=yes
				break
			fi
			n=$((n + 1))
		done
		[ "$found" = yes ] && continue
		case "$level" in
			error)
				echo "ERROR: $INSTALLER:$lineno: comando destructivo sin comprobar el exit code:" >&2
				echo "    $line" >&2
				errors=$((errors + 1))
				;;
			warn)
				echo "AVISO: $INSTALLER:$lineno: copia sin comprobar:" >&2
				echo "    $line" >&2
				warns=$((warns + 1))
				;;
			info)
				# Las copias de config no se comprueban a proposito (upstream
				# tampoco): si fallan falta ficheros en el target, pero no se
				# pierde disco ni el target queda a medias.
				echo "INFO: $INSTALLER:$lineno: copia de config sin comprobar (no destructivo)" >&2
				;;
		esac
	done <"$INSTALLER"
}

audit "$destructive" error
audit "$copies" info

if [ "$errors" -ne 0 ]; then
	echo
	echo "$errors comando(s) destructivo(s) sin comprobar en $INSTALLER." >&2
	echo "Anade el patron de upstream: if [ \$? -ne 0 ]; then DIALOG ...; DIE 1; fi" >&2
	exit 1
fi
echo "Instalador: todos los comandos destructivos comprueban su exit code ($warns avisos de copias)."
