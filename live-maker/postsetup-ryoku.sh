#!/bin/sh
# postsetup de Ryoku: garantiza un solo display manager.
#
# El flavor base de niri deja sddm habilitado en /var/service. Los flavors de
# Ryoku usan emptty (dm=emptty en el manifest), asi que sddm sobra: dos DMs
# peleandose por la tty7, y el que gana (sddm) no tiene autologin, con lo que
# el live se queda pidiendo contrasena en vez de entrar al escritorio.
#
# Se ejecuta desde mklive con el rootfs como primer argumento.
set -eu

rootfs=${1:?falta el rootfs}

if [ -e "$rootfs/var/service/sddm" ]; then
    rm -f "$rootfs/var/service/sddm"
fi

# emptty tiene que estar habilitado: es el DM del manifest y el que lleva
# AUTOLOGIN=true en el overlay.
if [ -d "$rootfs/etc/sv/emptty" ] && [ ! -e "$rootfs/var/service/emptty" ]; then
    ln -s /etc/sv/emptty "$rootfs/var/service/emptty"
fi
