# Ryoku en una ISO de Neko-Void (glibc) — guía completa

Guía para construir una imagen live de Neko-Void con **Ryoku** como escritorio, en
glibc, con **niri** o con **Hyprland**, y con el Ryoku **completo** dentro (shell,
Hub, pantalla de bloqueo, CLI, proveedor de compositor, plugins, portales).

Está escrita para alguien que **no sabe nada de Ryoku**. Cada término nuevo se
explica la primera vez que aparece. Al final hay una lista de los errores que te
vas a encontrar, con su síntoma exacto y su causa.

---

## 0. Qué vas a construir

Una **ISO live**: un pendrive (o un DVD, o un fichero `.iso`) que al arrancar
te mete un sistema Void Linux **completo** en la memoria del equipo, sin tocar
el disco. Desde ese sistema puedes navegar, jugar, trabajar y, si quieres,
instalar Void en el disco duro con un instalador de texto.

En vez del escritorio de Neko (MATE, KDE, XFCE, Labwc, niri...), lo que quieres
es **Ryoku**: un escritorio completo con su propio shell gráfico (una barra, un
lanzador, un hub de ajustes, una pantalla de bloqueo), hecho sobre Void.

Lo que Vas a conseguir:

| | |
|---|---|
| **Imagen** | `nekovoid-ryoku-n-YYYYMMDD.iso` (niri) o `nekovoid-ryoku-h-YYYYMMDD.iso` (Hyprland) |
| **Arrancable** | BIOS y UEFI (GRUB por defecto; Limine con `-b limine`) |
| **Escritorio** | Ryoku completo, con su shell, su Hub y su pantalla de bloqueo |
| **Instalador** | El instalador de texto de Neko, para pasar el live a un disco |

### 0.1. Qué es Ryoku, en cinco frases

1. Ryoku es un **escritorio** para Linux, como lo son GNOME o KDE: trae shell,
   panel, launcher, ajustes, bloqueo de pantalla y un montón de herramientas.
2. Se **distribuye como paquetes firmados**, no como una carpeta de dotfiles.
   En Void, esos paquetes viven en un repositorio XBPS propio.
3. El compositor (niri o Hyprland) **no es el escritorio**: es el servidor de
   ventanas. Ryoku funciona sobre cualquiera de los dos porque habla con él a
   través de una capa intermedia.
4. La configuración de Ryoku (el árbol de ficheros del compositor, el shell, los
   temas) viaja **dentro de los paquetes** y se copia a `~/.config` al instalar.
5. Por eso, para meter Ryoku en la ISO lo que hay que hacer es: **que los
   repos estén en la lista de repos**, **que sus claves estén en el keyring de
   la imagen**, **que sus paquetes estén en el set del flavor**, y **que su
   configuración esté en el overlay**.

### 0.2. Los dos repositorios que necesitas

| Repositorio | Qué sirve | Dónde vive |
|---|---|---|
| **Ryoku** (`repo.ryoku.dev`) | El escritorio entero: shell, Hub, lockscreen, CLI, variante del compositor, fuentes, temas | `https://repo.ryoku.dev/stable/void/channels/testing/x86_64` |
| **z-repo** (`SrDicov/z-repo`) | El **carril de Hyprland**: el compositor y su pila (6 librerías, `lua55`, plugins, portales). Void no puede compilarlos (su toolchain es demasiado viejo), así que alguien los compiló y los firmó en un repo aparte | `https://github.com/SrDicov/z-repo/releases/download/stable` |

Las **claves** que los firman (una por repo):

| Repo | Huella de la clave |
|---|---|
| Ryoku | `d1:93:22:ea:fc:f3:28:2b:70:0a:14:63:9e:b4:f3:85` |
| z-repo | `02:16:21:e8:80:43:b6:16:d4:63:13:e5:5d:e1:32:b7` |

> **El nombre del fichero de la clave es la huella, con los dos puntos.** No es
> un detalle: xbps **ignora** cualquier fichero de `/var/db/xbps/keys/` que no
> se llame exactamente `<huella>.plist`. Está comprobado: con la clave copiada
> como `foo.pub`, xbps la ignora y pregunta si quieres importarla; con el
> nombre correcto, se fía en silencio.

---

## 1. El mapa mental: las cuatro capas

El `live-maker/` es un **andamiaje** que produce **21 imágenes** distintas
desde datos: la política vivía en un `case` de bash de 100 líneas repetido en
el YAML del CI, y hoy está en cuatro capas. Si entiendes esto, todo lo demás
cae solo.

```
CAPA 4  CI            .github/workflows/build-iso.yml      cómo se invoca y dónde se publica
CAPA 3  flavor        live-maker/flavors/<nombre>           QUÉ imagen: overlay, kernel, DM, paquetes, nombre
CAPA 2  overlay       live-maker/<escritorio>/              LOS DATOS: /etc, /home/anon, /usr, var/db/xbps/keys
CAPA 1  mecanismo     mklive.sh, mkiso.sh, lib.sh           CÓMO se hace: rootfs → initramfs → squashfs → ISO
```

Se lee de abajo arriba:

- **Capa 1 — el mecanismo** (`mklive.sh` y compañía) es **código de Void
  upstream**: sabe fabricar un rootfs, meterle un initramfs, comprimirlo en
  squashfs y montar una ISO hybrid. **No se toca.** Nunca.
- **Capa 2 — el overlay** es una carpeta de **datos puros**: ficheros que se
  copian encima del rootfs. No hay código, no hay decisiones: `etc/`,
  `home/anon/` (el usuario del live), `usr/share/` (temas, iconos) y
  `var/db/xbps/keys/` (las claves de confianza).
- **Capa 3 — el flavor** es un **fichero `key=value`** que dice qué overlay se
  usa, qué kernel, qué display manager, qué set de paquetes y cómo se llama la
  ISO. Es *la política*.
- **Capa 4 — el CI** es el que invoca el builder y publica el resultado.

El punto clave: **el builder, el `--help`, el menú interactivo y la matriz del
CI leen todos el mismo sitio** (`live-maker/flavors/`). Por eso **añadir una
imagen es añadir un fichero**, no coordinar tres ediciones.

### 1.1. El flujo de un build, en orden

```
neko-builder.sh <flavor> [-e "paquete"] [-b grub|limine]
   │
   ├─ 1. Lee flavors/<flavor>          → overlay, packages, kernel, dm, arch, iso
   ├─ 2. Expande ${!packages}          → la lista de paquetes (base-neko-pkgs.sh)
   ├─ 3. Materializa installer.sh en un overlay temporal
   │
   └─ 4. sudo ./mklive.sh [...]        → el motor de Void hace el resto
            ├─ Synchronizing XBPS repository data
            ├─ Installing void pkgs into the rootfs      ← los ~160 paquetes del flavor
            ├─ Enabling services                         ← dbus, NetworkManager, emptty…
            ├─ Copying directory structures into the rootfs ← AQUÍ entra el overlay (-I)
            ├─ Generating initramfs image
            ├─ Generating squashfs image (zstd)           ← el rootfs comprimido
            └─ Generating ISO image                       ← xorriso
```

El resultado es una ISO con esta estructura:

```
/boot/vmlinuz, /boot/initrd      kernel + initramfs
/boot/live.squashfs              el rootfs completo (el "disco" de solo lectura)
/boot/isolinux/                  boot BIOS (GRUB) o Limine
/EFI/BOOT/BOOTX64.EFI            arranque UEFI
```

El rootfs es la clave: **un sistema Void completo comprimido**. El kernel lo
monta en RAM con overlayfs (las escrituras van a la RAM) y de ahí sale el live.

---

## 2. El plan, en ocho pasos

| # | Qué haces | Dónde |
|---|---|---|
| 1 | Añadir los repos de Ryoku y del z-repo a la lista de repos del builder | `live-maker/neko-builder.sh` |
| 2 | Crear los sets de paquetes de Ryoku | `live-maker/base-neko-pkgs.sh` |
| 3 | Crear los overlays `ryoku-n/` y `ryoku-h/` | `live-maker/` |
| 4 | Crear los manifests `flavors/ryoku-n` y `flavors/ryoku-h` | `live-maker/flavors/` |
| 5 | Añadir los dos flavors a la matriz del CI | `.github/workflows/build-iso.yml` |
| 6 | Pasar la puerta de coherencia | `tools/check-coherence.sh` |
| 7 | Construir (en el CI) | `gh workflow run build-iso.yml` |
| 8 | Verificar la imagen (arrancarla y mirarla) | a mano |

---

## 3. Paso 1 — Los repositorios

### 3.1. Por qué hay que tocar el builder

El builder pasa a `mklive.sh` una lista de repos con `-r`. Esa lista es lo que
xbps usa **durante el build** para instalar los paquetes en el rootfs. Si el
paquete `ryoku-desktop` no está en un repo de esa lista, el build falla con:

```
ERROR: Package 'ryoku-desktop' not found in repository pool.
```

Ojo con una trampa: **un repo musl no puede estar en la lista glibc**. Un repo
musl no tiene `x86_64-repodata` (tiene `x86_64-musl-repodata`); xbps lo busca
igual al sincronizar y aborta con
`[reposync] failed to fetch ... Not Found`, tirando el build entero. La lista
glibc y la musl no se mezclan, y la puerta `check-coherence.sh` lo vigila.

### 3.2. El cambio exacto

En `live-maker/neko-builder.sh`, dentro de `build_iso()`, está el `if` que
separa glibc de musl. En la rama **glibc** (la `else`), añade dos líneas al
array `REPOS`:

```bash
    else
        REPOS=(
            -r https://github.com/xlibre-void/xlibre/releases/latest/download
            -r https://github.com/Neko-Void-Linux/repo-neko/releases/download/stable
            -r https://repo-de.voidlinux.org/current/nonfree
            -r https://repo-de.voidlinux.org/current
            -r https://repo-de.voidlinux.org/current/multilib/nonfree
            -r https://repo-de.voidlinux.org/current/multilib
            # ─── Ryoku ─────────────────────────────────────────────
            # El escritorio completo (shell, Hub, lockscreen, CLI) y la
            # variante del compositor. El canal testing es el unico publicado
            # de Void: stable/void/x86_64 responde 404.
            -r https://repo.ryoku.dev/stable/void/channels/testing/x86_64
            # El carril de Hyprland: Void no puede compilarlo (GCC 14 no tiene
            # #embed, operator+(string,string_view), ranges::starts_with ni
            # vector::insert_range), asi que viene firmado desde el z-repo.
            -r https://github.com/SrDicov/z-repo/releases/download/stable
        )
    fi
```

> **Solo en la rama glibc.** Si alguna vez haces la variante musl, ahí va
> `z-repo-musl` (otra URL, otra clave) y nunca el z-repo de glibc.

### 3.3. Los repos dentro de la imagen (para el live, no para el build)

Lo anterior es solo para **construir**. La imagen ya instalada tiene que
seguir viendo esos repos, para que el usuario pueda instalar cosas desde el
live. Eso se declara en el **overlay**, en `etc/xbps.d/`:

```bash
# live-maker/ryoku-n/etc/xbps.d/20-ryoku.conf
repository=https://repo.ryoku.dev/stable/void/channels/testing/x86_64

# live-maker/ryoku-h/etc/xbps.d/25-zrepo.conf
repository=https://github.com/SrDicov/z-repo/releases/download/stable
```

Las claves van en `var/db/xbps/keys/` del overlay (ver §5.4).

---

## 4. Paso 2 — El set de paquetes

### 4.1. Cómo está organizado `base-neko-pkgs.sh`

Ese fichero es una **biblioteca de listas**, no política. Hay *grupos*
(`FONTS`, `GAMING`, `AUDIO`…) y *sets compuestos* (`DEFAULT`, `NIRI_PACKAGES`).
El manifest del flavor dice el **nombre** del set, no la lista; el builder lo
expande con `${!packages}`.

El final del fichero exporta los `PACKAGES_*` que el builder lee:

```bash
PACKAGES_NIRI=$(echo ${NIRI_PACKAGES} | tr -s ' ')
```

### 4.2. El grupo de Ryoku

Añade al `base-neko-pkgs.sh` del live-maker (junto a los otros grupos, p. ej.
después de `NIRI=`), un grupo con los dos sets:

```bash
# ─────────────────────────────────────────────
# Ryoku
# ─────────────────────────────────────────────
# El escritorio de Ryoku. El compositor y su pila vienen del z-repo (Void no
# puede compilarlos); el shell, el Hub, la pantalla de bloqueo, la CLI y las
# apps que Ryoku trae de serie, del repositorio de Ryoku.
#
# No usan la lista NIRI de neko: Ryoku trae su propio compositor, su shell y
# sus temas, y el set NIRI instala noctalia y demas, que son la rice de neko.
RYOKU_N="
    ryoku-keyring
    ryoku-desktop
    ryoku-desktop-niri
    ryoku-keysounds-niri
    ryoku-rashin
    kitty
    ryotunes
    ryomanager
    bash-completion
    blesh
    fastfetch
    fish-shell
    gamemode
    gamescope
    gparted
    flatpak
    MangoHud
    nautilus
    nautilus-python
    neovim
    openrgb
    pavucontrol
    songrec
    starship
    waifu2x-ncnn-vulkan
    yazi
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    gtk-update-icon-cache
"

RYOKU_H="
    ryoku-keyring
    ryoku-desktop
    ryoku-desktop-hyprland
    ryoku-rashin
    kitty
    ryotunes
    ryomanager
    bash-completion
    blesh
    fastfetch
    fish-shell
    gamemode
    gamescope
    gparted
    flatpak
    MangoHud
    nautilus
    nautilus-python
    neovim
    openrgb
    pavucontrol
    songrec
    starship
    waifu2x-ncnn-vulkan
    yazi
    gvfs-afc
    gvfs-mtp
    gvfs-smb
    gtk-update-icon-cache
"
```

Y los sets compuestos + sus exports, al final del fichero (después de
`DEFAULT`, que es donde está definido):

```bash
# El set de neko (DEFAULT) no sirve tal cual en un escritorio Ryoku:
# TLP es excluyente con power-profiles-daemon (la politica de energia y tapa
# de Ryoku) y la instalacion aborta con "Transaction aborted due to conflicting
# packages"; y la rice de neko (temas, fuentes, el asistente, el instalador
# de Void) la sustituye Ryoku con la suya.
RYOKU_BASE=$(echo ${DEFAULT} | tr ' ' '\n' \
    | grep -vE '^(tlp|tlp-pd|tlp-rdw|kasha-installer|Neko-Wizard|neko-fonts|neko-icons|neko-themes|neko-backgrounds)$' \
    | tr '\n' ' ')

RYOKU_N_PACKAGES="
    ${RYOKU_BASE}
    ${RYOKU_N}
"

RYOKU_H_PACKAGES="
    ${RYOKU_BASE}
    ${RYOKU_H}
"

# … y junto a los demás exports:
PACKAGES_RYOKU_N=$(echo ${RYOKU_N_PACKAGES} | tr -s ' ')
PACKAGES_RYOKU_H=$(echo ${RYOKU_H_PACKAGES} | tr -s ' ')
```

`${RYOKU_BASE}` aporta lo mismo que `${DEFAULT}` a los demás escritorios:
repos de Void (`void-repo-nonfree`…), base del sistema, red, audio, drivers,
fuentes, multimedia y los extras de accesibilidad.

> **Ojo con `emptty`**: el display manager del live **no** está en `DEFAULT`,
> está en la lista del escritorio de neko (`NIRI=`). Un flavor nuevo que use
> emptty tiene que nombrarlo en su set, o la imagen no tiene login.

> **`ryoku-desktop` ya arrastra casi todo**: quickshell, Qt6, GTK3, webkit2gtk,
> mpv, grim, slurp, cava, matugen, ffmpeg, sddm, turnstile, NetworkManager,
> pipewire, wireplumber, polkit, bluez, las fuentes de Ryoku, sus cursores, su
> tema de iconos… El grupo de arriba solo añade lo que `ryoku-desktop` **no**
> declara: las apps que Ryoku trae de serie (fish, blesh, starship, yazi,
> neovim, nautilus, el daemon de rashin…) y las que quieres de neko.

---

## 5. Paso 3 — El overlay

### 5.1. Anatomía de un overlay

Un overlay es una carpeta de datos que se copia encima del rootfs:

```
live-maker/ryoku-n/
├── etc/                       configuración del sistema
│   ├── emptty/conf            el display manager del live (autologin)
│   ├── pam.d/…                reglas de autenticación
│   ├── xbps.d/…               repositorios declarados
│   └── …
├── home/anon/                 el usuario del live (dotfiles, configs)
│   └── .config/niri/          ← aquí va la config de Ryoku
├── usr/share/                 temas, iconos, fuentes
└── var/db/xbps/keys/          las claves de confianza de los repos
```

**Lo más cómodo para un flavor nuevo es partir de uno que ya exista.** El
overlay `niri/` de neko ya tiene el `pam.d`, el `alsa`, el `emptty` y los temas;
tu overlay es una copia con el compositor y los repos cambiados.

```bash
cd live-maker
cp -a niri ryoku-n
cp -a niri ryoku-h
```

### 5.2. La configuración del compositor (la parte de Ryoku)

Ryoku trae la configuración de su compositor como **ficheros sueltos**, en el
repositorio de Ryoku:

- `ryoku/niri/` → 9 ficheros KDL (`config.kdl`, `autostart.kdl`, `keyboard.kdl`,
  `gpu.kdl`, `lid.kdl`, `monitors.kdl`, `monitors_user.kdl`, `user.kdl`) más
  `niri-portals.conf`.
- `ryoku/hyprland/` → el árbol Lua completo (`hyprland.lua`, `modules/`,
  `scripts/`, `plugins/`, `shaders/`, `user.lua`, `keyboard.lua`…) más
  `hyprland-portals.conf`.

Cópialos al home del live:

```bash
# niri
mkdir -p ryoku-n/home/anon/.config/niri
cp -a /ruta/a/ryoku/ryoku/niri/. ryoku-n/home/anon/.config/niri/
rm -f ryoku-n/home/anon/.config/niri/niri-portals.conf
mkdir -p ryoku-n/home/anon/.config/xdg-desktop-portal
cp -a /ruta/a/ryoku/ryoku/niri/niri-portals.conf \
      ryoku-n/home/anon/.config/xdg-desktop-portal/

# hyprland
mkdir -p ryoku-h/home/anon/.config/hypr
cp -a /ruta/a/ryoku/ryoku/hyprland/. ryoku-h/home/anon/.config/hypr/
rm -f ryoku-h/home/anon/.config/hypr/hyprland-portals.conf
mkdir -p ryoku-h/home/anon/.config/xdg-desktop-portal
cp -a /ruta/a/ryoku/ryoku/hyprland/hyprland-portals.conf \
      ryoku-h/home/anon/.config/xdg-desktop-portal/
```

> **El portal.** `xdg-desktop-portal` decide qué backend handles cada cosa
> (compartir pantalla, abrir el selector de ficheros). Niri no tiene backend
> propio: usa el de GNOME pero con el FileChooser de GTK. El fichero
> `*-portals.conf` de Ryoku trae esa ruta; sin él, los selectores de fichero no
> abren.

### 5.3. El truco de los ficheros generados (esto es lo que más cuesta)

Ryoku separa su configuración en **lo que se envía** y **lo que se genera**:

- **Se envía**: el árbol de arriba (`config.kdl`, `hyprland.lua`…).
- **Se genera en runtime**: los ficheros que dependen de la máquina y de los
  ajustes del usuario. En niri son `settings.kdl` y `rebinds.kdl`; en Hyprland,
  `settings.lua` y `rebinds.lua`.

Y aquí está la trampa, porque **en niri es fatal**:

> El `config.kdl` de Ryoku hace `include "settings.kdl"` e `include
> "rebinds.kdl"`. En niri, **un include que no existe es un error de
> configuración**, y un niri con la configuración ilegible **no tiene sesión**:
> no arranca el escritorio.

En un escritorio ya instalado, esos ficheros los escribe el proveedor de
Ryoku (`ryoku-wm-niri apply`) en cada arranque, y `ryoku materialize` los
genera antes. En una ISO **no hay ese arranque todavía**: el live arranca, niri
lee la configuración, y si faltan esos dos ficheros, **no arranca**.

**Solución: méTELOS EN EL OVERLAY.** Genera los ficheros una vez (en una
máquina con Ryoku instalado) y cópialos al overlay:

```bash
# En una máquina con Ryoku instalado, como el usuario:
ryoku materialize                       # deja el store y la config compartida
ryoku-wm-niri apply ~/.config/ryoku/desktop.json
ryoku-wm-hyprland apply ~/.config/ryoku/desktop.json

# Y en el overlay:
cp /home/usuario/.config/niri/settings.kdl \
   /home/usuario/.config/niri/rebinds.kdl \
   ryoku-n/home/anon/.config/niri/
cp /home/usuario/.config/hypr/settings.lua \
   /home/usuario/.config/hypr/rebinds.lua \
   ryoku-h/home/anon/.config/hypr/
```

En el live, el proveedor los reescribe en el primer arranque con los valores
reales, así que no se quedan "congelados": son la semilla, no el estado.

> Hyprland es más indulgente: su configuración carga los ficheros generados con
> un `optional()` que degrada en silencio si no están. Por eso el flavour de
> Hyprland arranca aunque falten. **niri no perdona**: déjalos puestos.

### 5.4. Las claves de confianza

El rootfs tiene que confiar en los repos de Ryoku y del z-repo **antes** de
instalar nada de ellos. Para eso van en el overlay, en
`var/db/xbps/keys/`, con **el nombre de la huella**:

```bash
mkdir -p ryoku-n/var/db/xbps/keys ryoku-h/var/db/xbps/keys
cp /ruta/a/ryoku/void/packages/srcpkgs/ryoku-keyring/files/*.plist \
   ryoku-n/var/db/xbps/keys/
cp /ruta/a/ryoku/void/packages/srcpkgs/ryoku-keyring/files/*.plist \
   ryoku-h/var/db/xbps/keys/
```

Eso deja dos ficheros con estos nombres exactos:

```
d1:93:22:ea:fc:f3:28:2b:70:0a:14:63:9e:b4:f3:85.plist   ← clave del repo de Ryoku
02:16:21:e8:80:43:b6:16:d4:63:13:e5:5d:e1:32:b7.plist   ← clave del z-repo
```

> **Si te saltas este paso**, el build falla con
> `ERROR: Package 'ryoku-desktop' not found in repository pool` **aunque el repo
> esté en la lista**, porque xbps no confía en él. Es el error más confuso del
> proyecto: el repo está y el paquete no aparece.

> **Y las claves tienen que estar en el keyring del TARGET, no en el del
> contenedor.** Con `-r <root>` (que es como instala mklive), xbps lee el
> keyring **del root**, no el del sistema: sembrarlas en `/var/db/xbps/keys`
> del contenedor no sirve de nada, y la importación interactiva de la clave
> puede fallar ("Failed to import pubkey … Resource temporarily unavailable"),
> con lo que los paquetes salen con "the RSA signature is not valid" y la
> transacción aborta entera.
>
> El sitio donde sembrarlas es **el wrapper de xbps** (`xbps-install-musl.sh`),
> que es el pegamento entre el host y el target y ya existe para la arch y
> para los repos:

```bash
# en live-maker/xbps-install-musl.sh, antes de exec de xbps:
if [ -n "${NEKO_TRUST_KEYS:-}" ] && [ -n "$root" ]; then
    mkdir -p "$root/var/db/xbps/keys"
    cp -f "$NEKO_TRUST_KEYS"/*.plist "$root/var/db/xbps/keys/" 2>/dev/null || true
fi
```

```bash
# en live-maker/neko-builder.sh: de dónde salen las claves y cómo llegan
# hasta el wrapper (sudo limpia el entorno, así que van explícitas):
export NEKO_TRUST_KEYS="${includedir}/var/db/xbps/keys"
sudo env XBPS_INSTALL_CMD="$XBPS_INSTALL_CMD" NEKO_TRUST_KEYS="$NEKO_TRUST_KEYS" \
    ./mklive.sh "${REPOS[@]}" -i xz -s zstd -L 19 "${cmd_args[@]}"
```

> Si no tienes a mano esas plists, se derivan de la clave privada con
> `void/packages/repo/new-signing-key <clave.pem> <destino>` (la herramienta
> que usa el propio port). El nombre de salida ya es `<huella>.plist`.

### 5.5. El display manager del live

El live usa **emptty** (un getty con autologin), no lightdm. Su configuración
está en `etc/emptty/conf`. Lo que importa:

```ini
DEFAULT_USER=anon
AUTOLOGIN=true
AUTOLOGIN_SESSION=niri
```

Para el flavor de Hyprland:

```ini
AUTOLOGIN_SESSION=hyprland
```

> `AUTOLOGIN_SESSION` tiene que coincidir con el **nombre de la sesión** que
> exista en `/usr/share/wayland-sessions/` dentro de la imagen (`.desktop`).
> `niri` y `hyprland` los ponen sus respectivos paquetes ✓. Si no coincide,
> emptty cae a la selección manual y el live no entra solo.

### 5.6. Lo que el overlay de Ryoku NO necesita

- **No copies la config compartida de Ryoku** (el árbol `quickshell/`, el Hub,
  los temas): viaja dentro de los paquetes y `ryoku materialize` la coloca en
  `~/.config` en el primer arranque ✓.
- **No copies el instalador** (`void-installer`): su única fuente es
  `live-maker/installer.sh`, y el builder ya lo materializa en un overlay
  temporal ✓. Si lo copias en tu overlay, divergen dos forks.
- **No traigas el `pam.d/lightdm-autologin`** del `autologin/`: con emptty no
  se usa (el autologin de emptty es por config, no por PAM). El CI lo copia
  solo si falta, y un overlay con su propia versión gana.

---

## 6. Paso 4 — El manifest del flavor

Un flavor es un fichero `key=value` en `live-maker/flavors/`. Sin parser de
YAML, sin `eval`: la jerarquía se resuelve con una llamada recursiva.

```bash
# live-maker/flavors/ryoku-n
desc=Ryoku sobre niri (kernel mainline)
overlay=ryoku-n
packages=PACKAGES_RYOKU_N
kernel=linux-mainline
dm=emptty
arch=x86_64
iso=nekovoid-ryoku-n
```

```bash
# live-maker/flavors/ryoku-h
desc=Ryoku sobre Hyprland (kernel mainline)
overlay=ryoku-h
packages=PACKAGES_RYOKU_H
kernel=linux-mainline
dm=emptty
arch=x86_64
iso=nekovoid-ryoku-h
```

| Clave | Para qué |
|---|---|
| `desc` | El texto del `--help` y del menú interactivo |
| `overlay` / `overlay2` | Directorio(s) de overlay (el `-I` de mklive; puede repetirse) |
| `packages` | **Nombre** del set de `base-neko-pkgs.sh` (no la lista) |
| `kernel` | Paquete de kernel (`-v`): `linux-mainline`, `linux-lts`, `linux6.18` |
| `dm` | Display manager y servicios extra (`-S`) |
| `arch` | `x86_64` o `x86_64-musl` |
| `iso` | Prefijo del nombre de la ISO |
| `extra` | Paquetes extra propios del flavor |
| `postsetup` | Script que se ejecuta en el chroot del target (`-x`) |
| `base` | Hereda las claves que no defina de otro flavor |

**No hace falta tocar el `--help` ni el menú**: ambos se generan desde
`flavors/` ✓. Esa es la razón de ser de esta capa.

---

## 7. Paso 5 — El CI

En `.github/workflows/build-iso.yml`, la matriz es una lista literal de flavors:

```yaml
matrix:
  iso: ${{ fromJson(inputs.iso == 'all' && '["i3","icewm",…,"ryoku-n","ryoku-h",…]' || format('["{0}"]', inputs.iso)) }}
```

Añade `"ryoku-n"` y `"ryoku-h"` a esa lista (va en orden alfabético).

**Los pasos especiales por flavor** (los que el workflow hace "si este flavor es
este") son solo tres: el `.tar` extra de xfce, los módulos dracut de los
flavors NVIDIA y la clave del z-repo-musl. **El de Ryoku no necesita ninguno**:
el overlay ya lleva sus claves ✓.

---

## 8. Paso 6 — La puerta de coherencia

Antes de construir, el CI corre cinco puertas (~5 s en total). La que te
afecta al añadir flavors es `tools/check-coherence.sh`, que comprueba que:

1. Cada manifest define sus claves obligatorias (`desc`, `overlay`,
   `packages`, `kernel`, `dm`, `arch`, `iso`).
2. El overlay que nombra **existe**.
3. El set de paquetes que nombra **existe** en `base-neko-pkgs.sh`.
4. El `base=` de la herencia **existe**.
5. El builder y el CI solo invocan flavors que existen.
6. El `--help` anuncia exactamente los flavors que hay.

Pásala en local antes de gastar un build:

```bash
sh tools/check-coherence.sh
```

Si te dice que un flavor no está en la matriz del CI, es que falta el paso 5 ✓.

---

## 9. Paso 7 — Construir

### 9.1. En el CI (lo recomendado)

El workflow es de dispatch manual:

```bash
gh workflow run build-iso.yml --repo SrDicov/Neko-Void \
  --ref main -f iso=ryoku-n -f bootloader=limine
```

> **El `--repo` es el fork.** Los flavors `ryoku-*` no están en el upstream
> (`Neko-Void-Linux/Neko-Void`): solo existen en el fork, así que un dispatch
> contra el upstream construye la imagen sin Ryoku o falla.
>
> **El `--ref` es la rama que quieres construir.** Sin `--ref`, el dispatch usa
> la rama por defecto (`main`): si tus commits están en otra rama, el CI
> construye el código viejo sin avisar. Pasó y el build murió en "Enabling
> services" con un `services=` que `main` todavía no tenía.

| Entrada | Valores |
|---|---|
| `iso` | `all` o el nombre de un flavor |
| `bootloader` | `grub` (por defecto) o `limine` |
| `upload_sourceforge` | `true`/`false` |

> **Un build a la vez.** El workflow tiene
> `concurrency: {group: neko-build-${{ github.ref }}, cancel-in-progress: true}`:
> si despachas dos flavors a la vez, **el segundo cancela al primero** (y el
> primero muere en segundos con `cancelled`). Encadénalos: espera a que uno
> termine y lanza el siguiente.

El build va en `docker run --privileged` con la imagen de Void glibc
(`ghcr.io/void-linux/void-glibc:20261001R1`), porque hace falta montar el
squashfs en un dispositivo loop.

**Un paso en verde no significa que la ISO exista.** Si el build no dejó
ninguna ISO, el paso de checksums falla con *"No se ha generado ninguna ISO"* y
el listado del directorio. Mira ese paso, no el primero.

### 9.2. En local

Hace falta **Void Linux privilegiado** (la imagen de glibc de Void), `sudo` y el
**módulo `loop`** en el kernel. Sin el módulo loop, mklive genera un squashfs
**vacío de 26 KB** y la ISO sale de 290 MB **sin avisar**.

```bash
cd live-maker
sudo bash neko-builder.sh ryoku-n -b limine
```

Tiempos medidos: descarga de paquetes 1–8 min (con cache, 1 min) · initramfs
49 s · squashfs zstd-19 3 min (con zstd-22, 7 min) · remasterizado a Limine
2 s.

---

## 10. Paso 8 — Verificar la imagen

Dentro del live (arráncala en una máquina de verdad o en QEMU), la lista:

```bash
# ¿el compositor está?
Hyprland --version          # o: niri --version
Hyprland --verify-config    # debe decir "config ok"
niri validate               # debe decir "config is valid"

# ¿el Ryoku está completo?
ryoku status
ryoku doctor                 # los "!"/"✗" que sobren son del entorno (sin GPU…)

# ¿la sesión de Ryoku?
ls ~/.config/service/        # ryoku-shell, pipewire, ryoku-bootstrap, turnstile-ready…
ls /etc/sv/ | head           # los servicios del sistema

# ¿los repos y las claves?
ls /var/db/xbps/keys/
xbps-query -R ryoku -Rs ryoku-desktop
```

Y en la ISO, antes de grabarla:

```bash
# el rootfs tiene el carril de Ryoku
ls /run/initramfs/live/…      # lo que ve el live montado
```

---

## 11. Los errores que te van a pasar

### 11.1 `Package 'ryoku-desktop' not found in repository pool`

**Causa**: el repo está en la lista `-r` pero su clave no está en
`/var/db/xbps/keys/`, así que xbps no se fía y no lo consulta.

**Arreglo**: meter la plist en el overlay con el nombre de la huella (§5.4).

### 11.2 `Transaction aborted due to conflicting packages`

**Causa**: `tlp-pd` (el set de neko) es excluyente con
`power-profiles-daemon`, que `ryoku-desktop` declara como dependencia. Los dos
gestionan los perfiles de energia y xbps no los deja coexistir.

**Arreglo**: el set de Ryoku no usa el de neko tal cual. Excluye TLP (que
ademas no hace falta: la politica de energia y tapa la lleva Ryoku) y la rice
de neko, que Ryoku sustituye con la suya (§4.2).

### 11.3 El repo está, la clave está, y aun así no aparece

**Causa**: la clave se copió con otro nombre (`foo.pub`, `ryoku.key`). xbps
ignora los ficheros de `/var/db/xbps/keys/` que no se llamen
`<huella>.plist` (verificado: con `foo.pub` xbps vuelve a pedir la clave).

**Arreglo**: renombrar la plist a su huella, con los dos puntos.

El mismo sintoma aparece si la clave esta bien pero **la importacion
interactiva falla** ("Failed to import pubkey ... Resource temporarily
unavailable"): entonces xbps no tiene la clave en el keyring que usa. Con `-r
<root>` (y el wrapper exportando `XBPS_ROOT`) ese keyring es el del **target**,
no el del contenedor: mklive copia `live-maker/keys/*.plist` a cada rootfs
antes de sincronizar (`mklive.sh:118`) y el wrapper siembra ademas las claves
del overlay (`NEKO_TRUST_KEYS`). Si la clave solo esta en el overlay, un build
que llame a mklive sin pasar por el wrapper vuelve a fallar: por eso las claves
de los repos de la imagen van tambien en `live-maker/keys/` (§5.4).

### 11.4 `[reposync] failed to fetch ... Not Found` y el build entero cae

**Causa**: un repo **musl** en la lista glibc. No tiene `x86_64-repodata`.

**Arreglo**: quitarlo. La lista glibc y la musl no se mezclan, y
`check-coherence.sh` lo vigila.

### 11.5 El live arranca y se queda en negro

**Causa**: faltan `settings.kdl` y `rebinds.kdl` en el árbol de niri. En niri un
include ausente es un error de configuración, y no hay sesión.

**Arreglo**: meterlos ficheros generados en el overlay (§5.3).

### 11.6 `hyprpicker: broken, unresolvable shlib 'libhyprutils.so.10'`

**Causa**: el `hyprutils` viejo (0.11.0) y el nuevo (0.14.2) **no pueden
convivir**: viven en repos distintos y cada uno aporta un soname distinto
(`.so.10` y `.so.13`). Si el repo de Void entra en la imagen, el paquete
`hyprpicker` de Void (que enlaza el viejo) queda roto, y la transacción de
instalación aborta entera.

**Arreglo**: que gane el nuevo. El `hyprpicker` del z-repo (reconstruido contra
la pila nueva, revisión superior) sustituye al de Void, porque xbps elige la
versión mayor ✓. Si tu imagen usa el `hyprpicker` de Void, quítalo del set o
asegúrate de que el del z-repo está disponible.

### 11.7 El build falla a mitad de la descarga

**Causa**: los mirrors de Void se reindexan cada ~20 minutos y hay una ventana
en la que el índice y los ficheros no cuadran
(`Package 'jq' not found in repository pool`, `failed to download ...
signature`). Es infraestructura, no el build.

**Arreglo**: reintentar. El CI ya lo hace **3 veces** con 30 s de espera ✓.

### 11.8 El compositor no arranca en el live: "session not found"

**Causa**: `AUTOLOGIN_SESSION` en `etc/emptty/conf` no coincide con ningún
`.desktop` de `/usr/share/wayland-sessions/`.

**Arreglo**: usa `niri` o `hyprland`, exactamente como los nombra el paquete.

### 11.9 El live entra pero no hay shell de Ryoku

**Causa**: la configuración del compositor no llegó al home del live, o el
proveedor no puede escribir sus ficheros generados.

**Arreglo**: comprueba que `home/anon/.config/niri/` (o `hypr/`) existe en el
overlay, y que los permisos son de `anon` (el CI hace
`chown -R anon:anon "$OV"`).

### 11.10 `set -e` mata al instalador

**Causa**: `installer.sh` usa el código de salida de `dialog` (1 = "Atrás") y de
`grep` (1 = "sin coincidencia") como **control de flujo**. Con `errexit` el
instalador muere en el primer menú.

**Arreglo**: **no** pongas `set -e` en el instalador. Lo que hay es un lint
(`tools/check-installer.sh`) que exige que todo comando destructivo compruebe
su exit code. Si tocas `installer.sh`, pasa ese lint.

---

## 12. Recetas

| Quiero… | Cómo |
|---|---|
| Un flavor nuevo | `flavors/<nombre>` (8 líneas) + entrada en la matriz del CI. El check te avisa si te olvidas |
| Cambiar los paquetes de un flavor | Editar el set en `base-neko-pkgs.sh`, o `extra=` en el manifest, o `-e` en la línea de comandos |
| Añadir un tema o un fichero al live | Al overlay del flavor. Se copia encima del rootfs |
| Cambiar el kernel | `kernel=` en el manifest (`linux-mainline` / `linux-lts` / `linux6.18`) |
| Cambiar el display manager | `dm=` en el manifest (`lightdm` / `sddm` / `emptty`) |
| Que el live use Limine | `-b limine` (o `NEKO_BOOTLOADER=limine`) |
| Instalar Limine en un disco | En el live: `limine bios-install /dev/sdX` (el paquete `limine` va dentro de la ISO) |
| Arranque dualboot con Windows | Limine lo detecta (`efi_boot_entry`) o el chainload del MBR |

---

## 13. Qué NO trae la imagen (y por qué)

- **Los wallpapers de Ryoku** (234 MB). Son contenido, no configuración: los
  paquetes traen el tema y los colores, y el usuario elige su fondo en el Hub.
  Copiarlos duplicaría 234 MB en el repo para algo que cambia cada temporada.
- **Los "rices"** (el tema completo con su fondo). Son productos de la tienda
  de Ryoku: se descargan desde el Hub, no se hornean.
- **Una config "de fábrica" del usuario**: el overlay lleva la config del
  compositor, que es lo que define al escritorio; el resto lo pone
  `ryoku materialize` en el primer arranque.

---

## 14. Comprobación rápida de que lo has hecho bien

```bash
# 1. la coherencia del proyecto
sh tools/check-coherence.sh

# 2. los shells y los scripts del CI
sh tools/check-workflows.sh
shellcheck -S warning live-maker/flavor.sh tools/check-coherence.sh tools/check-installer.sh

# 3. el instalador comprueba sus errores
sh tools/check-installer.sh

# 4. el wrapper de xbps
sh tools/test-wrapper.sh

# 5. el manifest se lee bien
sh live-maker/flavor.sh ryoku-n desc
sh live-maker/flavor.sh ryoku-h packages

# 6. el builder conoce los flavors
bash live-maker/neko-builder.sh --help | grep ryoku
```

Si todo eso sale limpio y el build produce una ISO que arranca en el
compositor con el shell de Ryoku, la imagen está lista.

## 15. Lo que la ISO corrige por su cuenta

Ryoku se instala como paquetes firmados, así que la ISO no copia su código.
Hay dos excepciones, y las dos viven en `live-maker/ryoku-common/`, el
`overlay2` que comparten los flavors `ryoku-n` y `ryoku-h`:

- `usr/bin/ryoku-qylock-activate` (y su copia en `usr/sbin`): acota con
  `flock -w` los cerrojos del qylock y el drenaje de clientes del lockscreen.
  Sin eso, un `ryoku-shell` que arranca a la vez que el cutover del lockscreen
  se queda esperando un cerrojo que otro tiene, y el daemon no llega a
  arrancar.
- `usr/lib/ryoku/runit/user/ryoku-shell/{run,finish}`: el `run` espera a que
  termine el cutover de sesión antes de activar el qylock, y acota la
  activación; el `finish` acota con `timeout` sus dos llamadas. runsv no tiene
  orden de arranque, y turnstile lanza el shell en paralelo con
  `session-start`: ese `finish` sin plazo se quedaba colgado 27 minutos
  esperando a que alguien desbloqueara la pantalla.

Los ficheros son copias de `ryoku-void` con el arreglo aplicado (rama
`agent/qylock-deadlock`). Cuando esos cambios entren en el paquete publicado,
el overlay se borra.

El resto es selección de paquetes: `voxtype` y `ryoku-palette-bridge` están en
el set porque el escritorio instala un servicio de sesión para cada uno y, sin
el binario, su `run` hace `require_bin` y queda en `down`. Y `adduser.sh` copia
`/etc/skel` cuando el home ya venía del overlay: sin `.bashrc`, bash abre sin
prompt (`bash-5.3$`).
