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

`arch` es el sitio donde se declara el soporte por arquitectura. Hoy solo hay
`x86_64` y `x86_64-musl`: el resto de arquitecturas (`aarch64`, `armv7l`, `i686`)
viven en el toolkit upstream de void-mklive (`Makefile` + `mkplatformfs.sh` +
`mkimage.sh` + `platforms/`), que este repo **no** modifica.

`// ponytail: armv7l/aarch64/i686 sin build propio aquí. Si hacen falta, el
mecanismo es un flavor más (arch=...) y un bootloader por arch (Limine cubre
BIOS+UEFI en x86; arm32 necesita U-Boot/extlinux). No se implementa hasta que
haya hardware o usuario real.`


## Comprobación

`sh tools/check-coherence.sh` (también corre en CI antes del build) verifica que:

- todo manifest define las claves obligatorias y que sus overlays existen;
- el set de paquetes existe en `base-neko-pkgs.sh`;
- `base=` apunta a un flavor existente;
- el builder, el `--help` y la matrix del CI hablan de los mismos flavors;
- toda ruta citada por los workflows existe.

Si añades un flavor, actualiza también la lista `iso` del workflow
(`.github/workflows/build-iso.yml`): el check te lo dice si se te olvida.
