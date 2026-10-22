# AUDIT — Neko-Void (overnight 20261022-0333)

Base: `97c4f6c0` (main) → rama `agent/overnight-20261022-0333`.
Alcance: los flavors **ryoku-n / ryoku-h** (ISO con Ryoku, glibc, Limine) y el
mecanismo de claves/servicios que los rodea.

Estado de los runs originales:
- `39739323953` (ryoku-n) → failure
- `39740159129` (ryoku-h) → failure
- `39721735683` (labwc glibc, sin Ryoku) → success ⇒ la regresión era de Ryoku.

## Defectos

| # | Severidad | Defecto | Evidencia | Estado |
|---|---|---|---|---|
| D3 | **bloqueante** | El builder pasaba `-S "… tlp tlp-pd"` fijo; el set de Ryoku no instala TLP (Ryoku lleva `power-profiles-daemon`) → `mklive.sh:204` `die "service tlp not in /etc/sv"`. | Log de los dos runs (07:22:54 / 07:30:34). | ✅ corregido: `services=` en el manifest (`34d577d3`). Verificado que **los 4 servicios existen**: `ryoku-var-state` y `ryoku-boot-guard` vienen de `ryoku-desktop`, `turnstiled` de `turnstile`, `power-profiles-daemon` de su paquete. |
| D1 | medio (robustez) | La clave del repo de Ryoku (`d1:93:22…`) solo estaba en los overlays; el build dependía de que el wrapper la sembrara en el keyring del target. | `live-maker/keys` no la tenía. Verificado: con la clave en el keyring del target, el sync de Ryoku no pide importar nada y `ryoku-desktop` instala verificando la firma. | ✅ corregido (`40954397`): `live-maker/keys/d1:93:22….plist`, que mklive copia a **todos** los rootfs. |
| D2 | alto | `the RSA signature is not valid` en paquetes **de Void** (`libva-intel-driver-irql`, `font-JetBrainsMono`) en los dos runs. | El repo de Ryoku tiene 286 paquetes y **no sirve** esos dos ⇒ no es mezcla de repos. Falta aislar si es descarga corrupta o `.xbps` obsoleto en el caché. | 🔄 en curso: run `39811903912` con D1+D3 corregidos; si reaparece, se añade el borrado del `.xbps` que falló en el reintento del CI. |
| D4 | medio | `docs/ryoku-live.md` §11.3 **duplicado** y contradice §5.4 (keyring del contenedor vs del target). | Lectura del fichero. | ⏳ pendiente |
| D5 | bajo | §1 describe el `case` de 100 líneas y "19 imágenes": ya no existe y son 21 flavors. | `live-maker/flavors/` = 21. | ⏳ pendiente |
| D6 | bajo | §7 sitúa los flavors "entre `niri` y `swayfx`": `swayfx` no existe. | `live-maker/flavors/`. | ⏳ pendiente |
| D7 | medio | §9.1 manda construir en el upstream, que no tiene los flavors Ryoku. | `git rev-list --left-right` fork/upstream. | ⏳ pendiente |

## Hallazgos que se descartaron (y por qué)

- **"El overlay ryoku-n no trae la clave de Ryoku"**: falso. Mi primer `ls | head` truncó la lista; tiene las 10, igual que ryoku-h.
- **"El repo de Ryoku reempaqueta paquetes de Void"**: falso para los que fallaron; no están en su índice.
- **"El fallo de firma es de la clave del repo de Ryoku"**: falso; los paquetes que fallan son de Void y la clave de Ryoku ya se siembra correctamente.

## Gate

```bash
sh tools/check-coherence.sh && sh tools/check-workflows.sh && \
sh tools/check-installer.sh && sh tools/test-wrapper.sh && \
shellcheck -S warning live-maker/flavor.sh live-maker/neko-builder.sh \
    live-maker/xbps-install-musl.sh live-maker/postsetup-ryoku.sh tools/*.sh
```

Gate de integración: build real en el CI **desde la rama** (`--ref
agent/overnight-20261022-0333`; un dispatch sin `--ref` construye `main`, que
no tiene estos commits — pasó y se canceló el run `39811721566`).

## Progreso

- [x] AUDIT
- [x] D3 servicios (`services=` en el manifest) + verificación de que existen
- [x] D1 clave de Ryoku en `live-maker/keys`
- [ ] D2 firma de paquetes de Void (run `39811903912` en curso)
- [ ] D4 doc §11.3 duplicado
- [ ] D5 doc §1 obsoleto
- [ ] D6 doc §7 `swayfx`
- [ ] D7 doc §9.1 repo equivocado
- [ ] ISO ryoku-n (Limine) verde + QEMU BIOS/UEFI
- [ ] ISO ryoku-h (Limine) verde + QEMU BIOS/UEFI
