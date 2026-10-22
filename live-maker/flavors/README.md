# Flavors

Cada flavor es un fichero `key=value` en este directorio. Es la **única** política
del builder: el `neko-builder.sh`, su `--help`, el menú interactivo y el CI leen
aquí (con `live-maker/flavor.sh`). Un flavor nuevo = un fichero nuevo.

```
desc=MATE + Xorg (kernel mainline)
overlay=mate
packages=PACKAGES_XORG
kernel=linux-mainline
dm=lightdm
arch=x86_64
iso=nekovoid-mate
```

| Clave | Obligatoria | Qué es |
|---|---|---|
| `desc` | sí | Texto del `--help` y del menú |
| `overlay` | sí | Directorio overlay en `live-maker/` (`-I` de mklive) |
| `packages` | sí | Nombre del set de `base-neko-pkgs.sh` (`PACKAGES_*`) |
| `kernel` | sí | `-v` de mklive (`linux-mainline`, `linux-lts`, `linux6.18`…) |
| `dm` | sí | Servicios de display manager (`-S`): `lightdm`, `sddm tlp-pd`, `emptty` |
| `arch` | sí | `-a` de mklive: `x86_64` o `x86_64-musl` |
| `iso` | sí | Prefijo del nombre de la ISO (`nekovoid-<iso>-<fecha>.iso`) |
| `overlay2` | no | Segundo `-I` (solo `labwc-musl`: overlay musl sobre el de labwc) |
| `postsetup` | no | Script `-x` de mklive (se ejecuta en el chroot del target) |
| `extra` | no | Paquetes extra que se suman al set |
| `base` | no | Hereda de otro flavor las claves que no defina |

Los flavors del CI (`kde-nvidia`, `nvidia390`…) heredan con `base=` y añaden sus
paquetes con `extra=`. Cada uno tiene su `iso=` propio: antes `kde-nvidia` y
`nvidia580` generaban la misma ISO y se pisaban en el release.

## Multi-arch

Hay **dos caminos distintos**, y no se mezclan:

| Camino | Qué construye | Arches |
|---|---|---|
| **Flavors de Neko** (`flavors/`) | Las ISOs de marca (MATE, KDE, labwc…) | `x86_64`, `x86_64-musl` |
| **Toolkit upstream** (`Makefile`, `mkrootfs.sh`, `mkplatformfs.sh`, `mkimage.sh`, `platforms/`) | Rootfs/platformfs/imágenes de Void | `x86_64`, `aarch64`, `armv7l`, `armv6l`, `i686` (+ musl) |

El mapeo platform → arch está en `live-maker/lib.sh` (`set_target_arch_from_platform`,
línea 279): `rpi-aarch64*`/`pinebookpro*`/`asahi*` → aarch64, `rpi-armv7l*` → armv7l,
`rpi-armv6l*` → armv6l, `i686*` → i686, `x86_64*` → x86_64.

**Por qué los flavors no declaran aarch64**: sus overlays, el bootloader (GRUB/Limine) y
los repos de Neko son x86_64. Poner `arch=aarch64` en un manifest sería mentira: el
builder no lo puede hacer. `tools/check-coherence.sh` lo comprueba (una arch fuera de
{x86_64, x86_64-musl} es un error) y comprueba además que el toolkit upstream siga
intacto, para que nadie borre el camino multi-arch por un cleanup.

`// ponytail: armv7l/aarch64/i686 se construyen con el Makefile de upstream, no con
los flavors de Neko. Si alguna vez hace falta una ISO de Neko para otra arch, es un
flavor nuevo (con su overlay y su bootloader: Limine cubre BIOS+UEFI en x86, arm32
necesita U-Boot/extlinux) más el soporte multi-arch de mklive. No se implementa hasta
que haya hardware o usuario real.`



## Comprobación

`sh tools/check-coherence.sh` (también corre en CI antes del build) verifica que:

- todo manifest define las claves obligatorias y que sus overlays existen;
- el set de paquetes existe en `base-neko-pkgs.sh`;
- `base=` apunta a un flavor existente;
- el builder, el `--help` y la matrix del CI hablan de los mismos flavors;
- toda ruta citada por los workflows existe.

Si añades un flavor, actualiza también la lista `iso` del workflow
(`.github/workflows/build-iso.yml`): el check te lo dice si se te olvida.
