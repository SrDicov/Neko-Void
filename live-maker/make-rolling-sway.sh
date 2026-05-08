#!/bin/bash
# ==============================================================================
# NekoVoid Live ISO Builder: ROLLING-RELEASE (SwayFX / Wayland)
# ==============================================================================
set -e

ISO_NAME="nekovoid-rolling-sway.iso"
ISO_TITLE="NekoVoid Rolling Sway"

# Repositorios Base
REPOS_PKGS="void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"

# Lista de paquetes purgada de Xorg/MATE (Idéntica a la funcional de NoLibre)
PKGS_SWAYFX="base-system bash-completion dbus elogind turnstile grub xtools \
NetworkManager network-manager-applet bluez blueman pipewire wireplumber \
swayfx xorg-server-xwayland Waybar rofi mako swaybg swaylock sddm \
mesa-dri Vulkan-Tools kitty Thunar xarchiver gvfs-mtp gamemode MangoHud \
noto-fonts-emoji font-awesome nerd-fonts-symbols-ttf"

# Parches automáticos
[ -f "dracut/vmklive/display-manager-autologin.sh" ] && sed -i 's/Session=plasma.desktop/Session=sway/g' dracut/vmklive/display-manager-autologin.sh
[ -f "dracut/vmklive/adduser.sh" ] && sed -i 's/,_seatd,bluetooth//g' dracut/vmklive/adduser.sh

# Preparar inyección
mkdir -p includedir/etc/sddm.conf.d includedir/etc/skel/.config includedir/home/anon/.config

cat <<EOF > includedir/etc/sddm.conf.d/autologin.conf
[Autologin]
User=anon
Session=sway
EOF

# Compilar
sudo ./mklive.sh -I includedir -o "${ISO_NAME}" -T "${ISO_TITLE}" -p "${REPOS_PKGS} ${PKGS_SWAYFX}" \
    -S "dbus elogind turnstiled NetworkManager sddm bluetoothd polkitd"
