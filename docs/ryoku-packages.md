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

