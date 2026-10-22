#!/bin/sh
# postsetup de Ryoku: garantiza un solo display manager.
#
# El flavor base de niri deja sddm habilitado. Los flavors de Ryoku usan
# emptty (dm=emptty en el manifest), asi que sddm sobra: dos DMs peleandose
# por la tty7, y el que gana (sddm) no tiene autologin, con lo que el live se
# queda pidiendo contrasena en vez de entrar al escritorio.
#
# Se ejecuta desde mklive con el rootfs como primer argumento, antes de que
# mklive enlace los servicios, asi que se escribe donde mklive lo hace
# (/etc/runit/runsvdir/default/) y no en /var/service, que alli todavia es un
# symlink sin destino.
set -eu

rootfs=${1:?falta el rootfs}
enabled="$rootfs/etc/runit/runsvdir/default"

mkdir -p "$enabled"

# -L ademas de -e: en el rootfs recien copiado el enlace puede apuntar a un
# target que en el host no existe (symlink roto), y -e solo no lo ve.
rm -f "$enabled/sddm"

# emptty tiene que estar habilitado: es el DM del manifest y el que lleva
# AUTOLOGIN=true en el overlay.
if [ -d "$rootfs/etc/sv/emptty" ] && [ ! -e "$enabled/emptty" ] && [ ! -L "$enabled/emptty" ]; then
    ln -s /etc/sv/emptty "$enabled/emptty"
fi
