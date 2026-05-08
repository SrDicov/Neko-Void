#!/bin/bash
# ==============================================================================
# NekoVoid Live ISO Builder: NO-LIBRE (SwayFX / Wayland)
# ==============================================================================
set -e

ISO_NAME="nekovoid-sway.iso"
ISO_TITLE="NekoVoid Sway"
REPOS_PKGS="void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"

# --- CONFIGURACIÓN DE PAQUETES (Fiel a SwayFX) ---
BASE="base-system bash-completion cryptsetup dbus dialog elogind turnstile grub mdadm nano rtkit xtools tmux"
UTILS="7zip unrar zip xz btop fastfetch curl wget git xdg-user-dirs xdg-utils lvm2 polkit polkit-gnome udisks2 udiskie eudev openssh chrony"
NET="NetworkManager network-manager-applet wpa_supplicant bluez blueman"
AUDIO="pipewire wireplumber alsa-lib alsa-utils alsa-pipewire libjack-pipewire pavucontrol pamixer"
GRAPHICS="swayfx xorg-server-xwayland qt5-wayland qt6-wayland Waybar rofi mako swaybg swaylock swayidle grim slurp wl-clipboard ImageMagick"
DM="sddm qt5-graphicaleffects qt5-quickcontrols2 qt5-declarative"
DRIVERS="mesa mesa-dri mesa-vaapi vulkan-loader Vulkan-Tools libglvnd linux-firmware-intel linux-firmware-amd"
APPS="kitty Thunar thunar-archive-plugin xarchiver file-roller tumbler ffmpegthumbnailer gvfs gvfs-mtp gvfs-afc xfce4-settings ristretto mpv gparted"
GAMING="gamemode gamescope MangoHud"
FONTS="noto-fonts-emoji noto-fonts-ttf font-awesome nerd-fonts-symbols-ttf"

ALL_PKGS="${REPOS_PKGS} ${BASE} ${UTILS} ${NET} ${AUDIO} ${GRAPHICS} ${DM} ${DRIVERS} ${APPS} ${GAMING} ${FONTS}"
PACKAGES=$(echo ${ALL_PKGS} | tr -s ' ')

# --- FASE 1: PARCHEO ANTI-ERRORES (DRACUT) ---
echo "=> [1/4] Parcheando lógica de Dracut..."
[ -f "dracut/vmklive/display-manager-autologin.sh" ] && sed -i 's/Session=plasma.desktop/Session=sway/g' dracut/vmklive/display-manager-autologin.sh
[ -f "dracut/vmklive/adduser.sh" ] && sed -i 's/,_seatd,bluetooth//g' dracut/vmklive/adduser.sh

# --- FASE 2: PREPARACIÓN DEL INCLUDEDIR (SIN BORRADO ACCIDENTAL) ---
echo "=> [2/4] Preparando zona de carga..."
mkdir -p includedir/etc/sddm.conf.d includedir/etc/skel/.config includedir/home/anon/.config

# Inyectar Autologin SDDM
cat <<EOF > includedir/etc/sddm.conf.d/autologin.conf
[Autologin]
User=anon
Session=sway
EOF

# --- FASE 3: INYECCIÓN DE DOTFILES (Desde carpeta 'dots') ---
# Si tienes tus dotfiles en una carpeta llamada 'dots' en la raíz, se copiarán aquí.
if [ -d "../dots" ]; then
    echo "=> Inyectando dotfiles desde ../dots..."
    cp -r ../dots/* includedir/etc/skel/.config/
    cp -r ../dots/* includedir/home/anon/.config/
else
    echo "⚠️ AVISO: No se encontró la carpeta '../dots'. La ISO se creará con config base."
fi

# --- FASE 4: COMPILACIÓN ---
echo "=> [4/4] Iniciando mklive.sh..."
sudo ./mklive.sh -I includedir -o "${ISO_NAME}" -T "${ISO_TITLE}" -p "${PACKAGES}" \
    -S "dbus elogind turnstiled NetworkManager sddm bluetoothd polkitd"
