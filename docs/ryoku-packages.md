# Los paquetes de Ryoku en Void, por origen

Lista de referencia de qué necesita el escritorio Ryoku para funcionar en
totalidad, y de dónde sale cada paquete. Tres orígenes:

| Origen | Qué aporta |
|---|---|
| **Void oficial** | el sistema, las herramientas, las fuentes, los temas |
| **repo de Ryoku** (`repo.ryoku.dev`) | el escritorio en sí: shell, Hub, lockscreen, CLI, proveedor del compositor, cursores |
| **z-repo** (`SrDicov/z-repo`) | lo que Void no trae: el carril de Hyprland y el `hyprpicker` reconstruido |

El z-repo existe porque el toolchain de Void es demasiado viejo para
construir Hyprland (GCC 14 no tiene `#embed`, `operator+(string,string_view)`,
`ranges::starts_with` ni `vector::insert_range`). Compilados donde sí se puede,
firmados y servidos aparte.


## Rama niri

El set completo son **186 paquetes** (lane `desktop` del port).

De ellos, el z-repo aporta **2**:

   hyprpicker                     hyprpicker-0.4.7_3 reconstruye el de Void (hyprpicker-0.4.7_2)
   hyprutils                      hyprutils-0.14.2_7 reconstruye el de Void (hyprutils-0.11.0_1)

> `hyprpicker` es el selector de color de hyprwm. Void lo trae
> (0.4.7_2), pero enlaza `libhyprutils.so.10`, el soname del `hyprutils` viejo
> (0.11.0_1). El z-repo lo reconstruye contra la pila nueva (`libhyprutils.so.13`)
> y con revisión superior, así que gana al fusionarse los repos. Sin eso la
> transacción aborta con `unresolved shlib`.


## Rama Hyprland

El set completo son **200 paquetes** (lanes `desktop` + `hyprland`). De ellos, el
z-repo aporta **21**, que son el carril entero:

   aquamarine                     aquamarine-0.15.1_5 Void NO lo tiene
   hypr-dynamic-cursors           hypr-dynamic-cursors-0.1.0_2 Void NO lo tiene
   hyprcursor                     hyprcursor-0.1.13_6 Void NO lo tiene
   hyprglass                      hyprglass-0.11.0_2 Void NO lo tiene
   hyprgraphics                   hyprgraphics-0.5.1_4 Void NO lo tiene
   hyprgrass                      hyprgrass-0.8.2_2 Void NO lo tiene
   hyprland                       hyprland-0.56.2_2 Void NO lo tiene
   hyprland-preview-share-picker  hyprland-preview-share-picker-0.2.1_2 Void NO lo tiene
   hyprland-protocols             hyprland-protocols-0.8.0_1 Void NO lo tiene
   hyprlang                       hyprlang-0.6.8_4 Void NO lo tiene
   hyprpolkitagent                hyprpolkitagent-0.1.3_2 Void NO lo tiene
   hyprsunset                     hyprsunset-0.4.0_2 Void NO lo tiene
   hyprutils                      hyprutils-0.14.2_7 reconstruye el de Void (hyprutils-0.11.0_1)
   hyprwire                       hyprwire-0.3.1_5 Void NO lo tiene
   imgborders                     imgborders-1.0.2_2 Void NO lo tiene
   lua55                          lua55-5.5.1_3    reconstruye el de Void (lua55-5.5.1_1)
   ryoku-desktop-hyprland         ryoku-desktop-hyprland-0.1.0_1 Void NO lo tiene
   ryoku-hypr-plugins             ryoku-hypr-plugins-0.1.0_2 Void NO lo tiene
   ryoku-keysounds                ryoku-keysounds-0.1.0_2 Void NO lo tiene
   ryoku-keysounds-profiles       ryoku-keysounds-profiles-0.1.0_1 Void NO lo tiene
   xdg-desktop-portal-hyprland    xdg-desktop-portal-hyprland-1.4.1_4 Void NO lo tiene

Los seis de la pila (`aquamarine`, `hyprcursor`, `hyprgraphics`, `hyprlang`,
`hyprutils`, `hyprwire`) más `lua55` son reconstrucciones o versiones nuevas
de lo que Void trae, porque el compositor exige sonames que la versión de Void
no produce.


## El escritorio en sí (repo de Ryoku)

Viene del repositorio firmado de Ryoku, no del z-repo:

   ryoku                          ryoku-0.104.3.r5179.g50cec46_1
   ryoku-blobs                    ryoku-blobs-0.104.3.r5179.g50cec46_1
   ryoku-cursor-material          ryoku-cursor-material-1.0.0_1
   ryoku-cursors                  ryoku-cursors-2.0.7_1
   ryoku-desktop                  ryoku-desktop-0.104.3.r5179.g50cec46_1
   ryoku-desktop-niri             ryoku-desktop-niri-0.104.3.r5179.g50cec46_1
   ryoku-hub                      ryoku-hub-0.104.3.r5179.g50cec46_1
   ryoku-keyring                  ryoku-keyring-20261010_1
   ryoku-keysounds-niri           ryoku-keysounds-niri-0.104.3.r5179.g50cec46_1
   ryoku-keysounds-profiles       ryoku-keysounds-profiles-0.104.3.r5179.g50cec46_1
   ryoku-oh-my-zsh                ryoku-oh-my-zsh-0.1.0_1
   ryoku-palette-bridge           ryoku-palette-bridge-0.104.3.r5179.g50cec46_1
   ryoku-rashin                   ryoku-rashin-0.104.3.r5179.g50cec46_1
   ryoku-shell                    ryoku-shell-0.104.3.r5179.g50cec46_1
   ryogami                        ryogami-0.104.3.r5179.g50cec46_1
   prowl                          prowl-0.17.2_1

## Lo que aporta Void oficial

El resto del set: el sistema base, la red, el audio, las fuentes de Ryoku
(`ttf-*`), el tema GTK (`adw-gtk-theme`), `quickshell`, `mpv`, `grim`, `slurp`,
`cava`, `matugen`, `ffmpeg`, `pipewire`, `wireplumber`, `sddm`, `turnstile`,
`elogind`, `NetworkManager`, `polkit` y las apps de serie (fish, blesh,
starship, yazi, neovim, nautilus, kitty, ryotunes, ryomanager).


## Cómo semixed el z-repo en el set

El repo de Ryoku marca en `void/packages/translations.tsv` qué paquete viene de
dónde (`repo=ryoku`, `repo=zrepo`). El z-repo se declara en
`/etc/xbps.d/25-zrepo.conf` y su clave (huella `02:16:21:...`) se siembra en el
keyring del target antes de instalar: con `-r`, xbps lee el keyring del root,
no el del sistema, y sin la clave los paquetes salen con `the RSA signature is
not valid`.

## Catalogo completo del z-repo: lo que Void no tiene

El z-repo construye **116 paquetes**; de ellos, **112 no estan en Void**
oficialmente (y 4 reconstruyen un paquete que Void si trae, con la version
que el carril necesita).

De los que Void no trae, Ryoku usa **2** (niri) y **21** (hyprland), los de
arriba. Los otros **93** son la rice de neko (noctalia, neko-themes,
neko-icons, neko-fonts, neko-backgrounds, niri-settings, noctalia-greeter),
los binarios de terceros (zen-browser-bin, vesktop-bin, brave-bin,
waterfox-bin, mullvad-*, protonvpn-*, vscode-bin, opencode-bin, codex-bin,
onlyoffice-bin, reaper-bin, cpak-bin, heroic-games-bin, pear-desktop-bin,
portproton-bin, unityhub-bin, orcaslicer-bin, pineconemc-bin, windscribe-*
librewolf-bin, helium-browser-bin, goverlay-bin, halley-bin, locasend-bin,
vouru-bin, voxtype-bin, xwinwrap-nk, ydotool, ly, spicetify, faugus-launcher,
hydra-launcher-bin, trinity-launcher-ap, gvfs-*, not-st, vary, kyoz) y las
herramientas del propio Neko (neko-base, neko-themes, neko-icons, neko-fonts,
neko-backgrounds, Neko-Wizard, Neko-Kernel-Manager, iruka-xbps,
kasha-installer, jwmkit-neko, labwc-singularity, labwc-tweaks-qt, asusctl,
nvibrant, game-devices-udev, waifu2x-ncnn-vulkan, adw-gtk3, las fuentes
font-JetBrainsMono, font-fraunces, font-maple-mono-nf, font-space-grotesk, y
los temas de cursor bibata-cursor-theme, phinger-cursor-theme,
vimix-cursor-theme).

### Los 93 que no usa Ryoku

   Neko-Kernel-Manager              1.4.2_2
   Neko-Wizard                      9.0.23_1
   adw-gtk3                         6.5_1
   arxy                             0.6.3_1
   aseprite                         1.3.18.6_1
   asusctl                          6.4.0_1
   bibata-cursor-theme              2.0.7_1
   brave-bin                        1.96.59_1
   brave-origin-bin                 1.96.59_1
   cmuspp-void                      1.1.1_3
   codex-bin                        26.928.20755_2
   concord                          2.6.0_1
   cpak-bin                         2.13.4_1
   falcond                          2.0.14_9
   faugus-launcher                  2.4.2_1
   font-JetBrainsMono               2.304_1
   font-fraunces                    1.000_1
   font-maple-mono-nf               7.9_1
   font-space-grotesk               2.0.0_1
   game-devices-udev                1.1_1
   goverlay-bin                     1.9.3_1
   halley-bin                       0.5.7_1
   helium-browser-bin               0.18.1.1_1
   heroic-games-bin                 2.22.3_1
   hydra-launcher-bin               4.1.5_1
   hypridle                         0.1.8_1
   hytale-installer                 0.1.2_1
   iruka-xbps                       0.1.0_1
   jwmkit-neko                      26.5_1
   kasha-installer                  7.4_5
   kyoz                             2026_2
   labwc-singularity                0.9.5_3
   labwc-tweaks-qt                  0.1.0_2
   libqt6pas-bin                    6.2.10_4
   librewolf-bin                    153.0.4.1_1
   libudev-zero                     1.0.5_1
   libva-intel-driver-irql          2.4.5_1
   linux-cachy-void-bin             7.3_10
   linux-neko-rt-bin                7.3.0_4
   linux-neko-zen-bin               7.2_7
   localsend-bin                    1.18.2_1
   ly                               1.5.0.1_16
   mullvad-browser-bin              15.0.23_1
   mullvad-vpn-bin                  2026.5_1
   neko-backgrounds                 7.1_2
   neko-base                        2026_2
   neko-fonts                       7.0_1
   neko-icons                       6.5_1
   neko-themes                      7.1_1
   niri-settings                    2026_4
   noctalia                         5.11.1_9
   noctalia-greeter-latest          1.6.0_1
   not-st                           0.9.3.1_1
   nvibrant                         1.3.0_1
   onlyoffice-bin                   9.4.0_1
   opencode-bin                     1.18.33_1
   orcaslicer-bin                   2.4.2_1
   pam-fprint-grosshack             0.4.0_1
   pavoldcontrol-git                r1.676d599_3
   pear-desktop-bin                 3.12.0_1
   phinger-cursor-theme             2.2_1
   pineconemc-bin                   11.1.0_1
   portproton-bin                   1.7.5.0_3
   protonup-qt                      2.15.1_1
   protonvpn-api-core               5.8.3_1
   protonvpn-cli                    1.0.5_1
   protonvpn-core                   0.7.4_1
   protonvpn-gui                    4.18.5_1
   protonvpn-local-agent            1.6.3_1
   python3-inputs                   0.5_1
   python3-steam                    2.0.0alpha1_1
   python3-vdf-dev                  4.0_1
   qrunsvmgr-git                    r14.e3a3023_1
   raven-polkit                     0.1.4_2
   reaper-bin                       7.81_1
   singularity-desktop              0.1.0_4
   spicetify                        2.45.1_1
   trinity-launcher-ap              20261002_1
   unityhub-bin                     3.22.0_2
   vary                             0.4.1_1
   vesktop-bin                      1.6.7_1
   vimix-cursor-theme               2020.02.24_1
   vouru-bin                        3.3_1
   voxtype-bin                      1.1.1_1
   vscode-bin                       1.139.1_1
   waifu2x-ncnn-vulkan              20250915_1
   waterfox-bin                     6.7.4_1
   windscribe-desktop-bin           2.22.10_3
   xwinwrap-nk                      1.0_3
   ydotool                          1.0.4_1
   zen-browser-bin                  1.22.3b_1
   zerotierone                      1.16.2_1
   zig-nk-bin                       0.16.0_1

### Los 4 que reconstruyen lo que Void ya trae

   hyprutils                        z-repo 0.14.2_7         | Void: hyprutils-0.11.0_1
   lua55                            z-repo 5.5.1_3          | Void: lua55-5.5.1_1
   re2                              z-repo 2025.11.05_1     | Void: re2-2025.11.05_2
   xbps-triggers                    z-repo 0.131_1          | Void: xbps-triggers-0.131_1

## El escritorio en si (repo de Ryoku, no z-repo)

   ryoku                          ryoku-0.104.3.r5179.g50cec46_1
   ryoku-blobs                    ryoku-blobs-0.104.3.r5179.g50cec46_1
   ryoku-cursor-material          ryoku-cursor-material-1.0.0_1
   ryoku-cursors                  ryoku-cursors-2.0.7_1
   ryoku-desktop                  ryoku-desktop-0.104.3.r5179.g50cec46_1
   ryoku-desktop-niri             ryoku-desktop-niri-0.104.3.r5179.g50cec46_1
   ryoku-hub                      ryoku-hub-0.104.3.r5179.g50cec46_1
   ryoku-keyring                  ryoku-keyring-20261010_1
   ryoku-keysounds-niri           ryoku-keysounds-niri-0.104.3.r5179.g50cec46_1
   ryoku-keysounds-profiles       ryoku-keysounds-profiles-0.104.3.r5179.g50cec46_1
   ryoku-oh-my-zsh                ryoku-oh-my-zsh-0.1.0_1
   ryoku-palette-bridge           ryoku-palette-bridge-0.104.3.r5179.g50cec46_1
   ryoku-rashin                   ryoku-rashin-0.104.3.r5179.g50cec46_1
   ryoku-shell                    ryoku-shell-0.104.3.r5179.g50cec46_1
   ryogami                        ryogami-0.104.3.r5179.g50cec46_1
   prowl                          prowl-0.17.2_1

