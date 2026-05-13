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

NETWORKING="
    NetworkManager
    network-manager-applet
    wpa_supplicant
    iw
"

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

XORG="
    xorg
    xorg-video-drivers
    orca
"

GPU_DRIVERS="
    nvidia
    nvidia-libs-32bit
    mesa
    mesa-dri
    mesa-vaapi
    vulkan-loader
    Vulkan-Tools
    libglvnd
    linux-firmware
"

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

FLATPAK="
    flatpak
    xdg-desktop-portal
    xdg-desktop-portal-gtk
"

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

MULTIMEDIA="
    ffmpeg
    gstreamer1
    gst-plugins-base1
    gst-plugins-good1
    gst-plugins-bad1
    gst-plugins-ugly1
"

GAMING="
    steam
    gamemode
    MangoHud
"

OTHER="
    ntp
    zramen
"

ACCESSIBILITY="
    espeakup
    brltty
"

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

PACKAGES=$(echo ${ALL_PACKAGES} | xargs)

echo "============================================="
echo " NekoVoid Live ISO Builder (RTX 5060 Ti)"
echo "============================================="
echo ""
echo "ISO de salida: ${ISO_NAME}"
echo "Paquetes totales: $(echo ${PACKAGES} | wc -w)"
echo ""

./mklive.sh \
    -I includedir \
    -o "${ISO_NAME}" \
    -T "${ISO_TITLE}" \
    -p "${PACKAGES}" \
    -S "dbus NetworkManager lightdm polkitd rtkit sshd chronyd zramen" \
    -C "live.autologin live.user=anon live.accessibility"
