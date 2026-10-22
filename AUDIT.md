# AUDIT — Neko-Void (overnight 20261022-0333)

Base: `97c4f6c0` (main) → rama `agent/overnight-20261022-0333`.
Alcance: los flavors **ryoku-n / ryoku-h** (los dos últimos, rotos), el mecanismo
de claves de confianza que surrounding, el builder y el doc que los describe.

Estado real medido (no supuesto):
- `39739323953` (ryoku-n) → **failure**
- `39740159129` (ryoku-h) → **failure**
- `39721735683` (labwc glibc, sin Ryoku) → **success** ⇒ la regresión es de los
  flavors con Ryoku, no del mecanismo general.

## Defectos (verificados)

| # | Severidad | Defecto | Evidencia | Fix previsto |
|---|---|---|---|---|
| D1 | **bloqueante** | La clave del repo de Ryoku (`d1:93:22:ea:fc:f3:28:2b:70:0a:14:63:9e:b4:f3:85`) **no está en `live-maker/keys/`**, así que mklive no la copia al rootfs y xbps no puede verificar los paquetes de Ryoku → `the RSA signature is not valid` → transacción abortada. El overlay `ryoku-n/` tampoco la trae (solo `00:ca:42…`); `ryoku-h/` sí. | Local, en la imagen exacta del CI: sin la clave → `Failed to import pubkey … Resource temporarily unavailable`; con la clave → sync de los 3 repos limpio + `ryoku-keyring` instala verificando la firma. | `live-maker/keys/d1:93:22….plist` (mklive lo copia a **todo** rootfs, `mklive.sh:118`) + el overlay `ryoku-n/` (para que el live también confíe) |
| D2 | alto | El CI conserva los `.xbps` del caché (1,8 GB) y solo borra los índices (`build-iso.yml:140`). Un paquete re-empaquetado por Void conserva la versión → el `.xbps` cacheado queda con firma vieja → `the RSA signature is not valid` al verificarlo contra el índice nuevo. Por eso el paquete que falla **cambia** entre builds (`libva-intel-driver-irql` → `font-JetBrainsMono`). | Comentario ya presente en el workflow para el caso del índice; el `.xbps` es el mismo problema con la parte pesada. | En el reintento, borrar los `.xbps` del caché del target |
| D3 | **bloqueante** | El builder pasa `-S "… tlp tlp-pd"` a mklive, pero el set de Ryoku **no instala TLP** (Ryoku lleva la política de energía) → `mklive.sh:203` → `die "service tlp not in /etc/sv"` → build muerto en la fase de servicios. | Log de los dos runs: `ERROR: service tlp not in /etc/sv` (07:22:54 / 07:30:34). `neko-builder.sh:55` vs `base-neko-pkgs.sh:797` (RYOKU_BASE quita tlp). | `-S` condicional: TLP solo si el set de paquetes lo trae + **puerta mecánica** en `check-coherence.sh` |
| D4 | medio | `docs/ryoku-live.md` §11.3 está **duplicado literal** (líneas 760-770) y las dos copias se contradicen: dice sembrar las claves en el keyring del **contenedor**, cuando §5.4 (y el código) las siembran en el del **target**. | Lectura del fichero (889 líneas). | Reescribir §11.3 una vez, coherente con §5.4 y con el mecanismo real |
| D5 | bajo | `docs/ryoku-live.md` §1 describe un estado que ya no existe ("un `case` de bash de 100 líneas", "19 imágenes"): quedan **21** flavors y el `case` se sustituyó por los manifests. | `live-maker/flavors/` = 21 manifests. | Corregir §1 |
| D6 | bajo | `docs/ryoku-live.md` §7 sitúa los flavors nuevos "entre `niri` y `swayfx`": **`swayfx` no existe** en este repo. | `live-maker/flavors/`. | Corregir §7 |
| D7 | medio | `docs/ryoku-live.md` §9.1 manda construir en `--repo Neko-Void-Linux/Neko-Void` (upstream): los flavors ryoku **no están** ahí, solo en el fork → el comando construye la imagen sin Ryoku o falla. | `git rev-list --left-right --count origin/main...fork/main` → el upstream no tiene los commits de Ryoku. | Corregir §9.1 (fork) y aclarar el alcance |

## Fuera de alcance (anotado, no se toca)

- La fila "19 flavors" del `README.md` raíz y del `live-maker/README.md` (generado).
- La venta de wallpapers/rices (§13 del doc): decisión de producto, no un defecto.
- Los flavors NVIDIA: no arrancables en QEMU (documentado con `// ponytail:`).

## Gate (lo que tiene que estar en verde antes de cada commit)

```bash
sh tools/check-coherence.sh
sh tools/check-workflows.sh
sh tools/check-installer.sh
sh tools/test-wrapper.sh
shellcheck -S warning live-maker/flavor.sh live-maker/neko-builder.sh \
    live-maker/xbps-install-musl.sh tools/*.sh
```

Gate de integración (caro, 20 min): build real de `ryoku-n` y `ryoku-h` en el CI.
Un paso verde **no** es un build: el artefacto es la ISO.

## Progreso

- [x] AUDIT escrito
- [ ] D1 clave de Ryoku en `live-maker/keys/` + overlay `ryoku-n`
- [ ] D2 caché: borrar `.xbps` en el reintento
- [ ] D3 servicios condicionales + puerta mecánica
- [ ] D4 doc: §11.3 duplicado
- [ ] D5 doc: §1 obsoleto
- [ ] D6 doc: §7 `swayfx`
- [ ] D7 doc: §9.1 repo equivocado
- [ ] Build real ryoku-n + ryoku-h en verde
