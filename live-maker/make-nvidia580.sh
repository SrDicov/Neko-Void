#!/bin/bash
set -e

# ─── Configuración de salida ───
ISO_NAME="nekovoid-rtx5060ti-ryzen7.iso"
ISO_TITLE="NekoVoid RTX 5060 Ti Edition"

# ─── Repositorios ───
REPOS_PKGS="void-repo-nonfree void-repo-multilib"

# ─── Sistema base y utilidades ───
BASE_SYSTEM="
    base-system
    at-spi2-core
    bash-completion
    cryptsetup
    dbus
    dialog
    elogind
    grub
    mdadm
    nano
    rtkit
    xdo
    xsetroot
    xinit
    Neko-Wizard
    xtools
    tmux
"

SYSTEM_UTILS="
    p7zip
    unrar
    zip
    unzip
    xz
    vim-common
    btop
    fastfetch
    curl
    wget
    git
    xdg-user-dirs
    xdg-utils
    ethtool
    iproute2
    lvm2
    polkit
    udisks2
    eudev
    void-docs-browse
    xtools-minimal
    openssh
    chrony
"

# ─── Networking ───
NETWORKING="
    NetworkManager
    network-manager-applet
    wpa_supplicant
    iw
"

# ─── Audio (PipeWire) ───
AUDIO="
    pipewire
    wireplumber
    alsa-lib
    alsa-utils
    alsa-pipewire
    libjack-pipewire
    pavucontrol
    pulsemixer
    rsync
    volumeicon
"

# ─── Xorg + Drivers NVIDIA ───
XORG="
    xorg
    xorg-video-drivers
    orca
"

GPU_DRIVERS="
    nvidia
    nvidia-libs-32bit
    nvidia-settings
    mesa
    mesa-dri
    mesa-vaapi
    vulkan-loader
    vulkan-tools
    libglvnd
    linux-firmware
    amd-ucode
"

# ─── Escritorio MATE ───
MATE_DESKTOP="
    mate
    mate-extra
    mate-tweak
    mate-polkit
    mate-terminal
    pluma
    caja-wallpaper
    caja-sendto
    caja-open-terminal
    caja-extensions
    atril
    gnome-screenshot
    gnome-keyring
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    lightdm
    lightdm-webkit2-greeter
    lightdm-gtk-greeter-settings
    libnotify
    numlockx
    picom
    lxappearance
"

# ─── Aplicaciones ───
DESKTOP_APPS="
    firefox
    ristretto
    geany
    mpv
    arandr
    xarchiver
    gparted
    gnome-software
"

# ─── Flatpak ───
FLATPAK="
    flatpak
    xdg-desktop-portal
    xdg-desktop-portal-gtk
"

# ─── Fuentes ───
FONTS="
    noto-fonts-emoji
    noto-fonts-cjk
    noto-fonts-ttf
    font-awesome
    dejavu-fonts-ttf
    liberation-fonts-ttf
    font-misc-misc
    terminus-font
"

# ─── Multimedia ───
MULTIMEDIA="
    ffmpeg
    gstreamer1
    gst-plugins-base1
    gst-plugins-good1
    gst-plugins-bad1
    gst-plugins-ugly1
"

# ─── Soporte 32-bit para Steam y NVIDIA ───
MULTILIB_32BIT="
    mesa-32bit
    mesa-dri-32bit
    nvidia-libs-32bit
"

# ─── Gaming ───
GAMING="
    steam
    gamemode
    MangoHud
"

# ─── Otros ───
OTHER="
    ntp
    zramen
"

# ─── Accesibilidad ───
ACCESSIBILITY="
    espeakup
    void-live-audio
    brltty
"

# ─── Construcción de la lista de paquetes ───
ALL_PACKAGES="
    ${REPOS_PKGS}
    ${BASE_SYSTEM}
    ${SYSTEM_UTILS}
    ${NETWORKING}
    ${AUDIO}
    ${XORG}
    ${GPU_DRIVERS}
    ${MATE_DESKTOP}
    ${DESKTOP_APPS}
    ${FLATPAK}
    ${FONTS}
    ${MULTIMEDIA}
    ${GAMING}
    ${OTHER}
    ${ACCESSIBILITY}
"

# Limpiar espacios y convertir a una sola línea
PACKAGES=$(echo ${ALL_PACKAGES} | xargs)

echo "============================================="
echo " NekoVoid Live ISO Builder (RTX 5060 Ti)"
echo "============================================="
echo ""
echo "ISO de salida: ${ISO_NAME}"
echo "Paquetes totales: $(echo ${PACKAGES} | wc -w)"
echo ""

sudo ./mklive.sh \
    -I includedir \
    -o "${ISO_NAME}" \
    -T "${ISO_TITLE}" \
    -p "${PACKAGES}" \
    -S "dbus NetworkManager lightdm polkitd rtkit sshd chronyd zramen" \
    -C "live.autologin live.user=anon live.accessibility"
