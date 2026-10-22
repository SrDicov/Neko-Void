# Overlays removidos

Payload que se borró del repo por no tener ningún target que lo usara. La
historia de git es el backup: todo lo de aquí se recupera con un comando.

## `live-maker/openbox/`

- **Qué era**: overlay completo de Openbox (5.576 ficheros, 58 MB: temas,
  iconos Chicago95, scripts de menú).
- **Por qué se borró**: ningún target lo usaba — no estaba en el `case` de
  `build_iso()`, ni en la matrix del CI, ni lo referenciaba ningún script.
  Los otros 12 overlays sí tenían target.
- **Cuándo**: commit `11567e5f` ("live-maker: borra codigo muerto"), que
  junto con las 22 copias vendoradas de `installer.sh` explica el −566.556
  líneas del refactor (533.777 = el 94% son de este overlay).
- **Cómo recuperarlo**: `git checkout 98c570b2 -- live-maker/openbox`
- **Si vuelve**: necesita su `flavors/openbox/manifest` (overlay, packages,
  kernel, dm, arch, iso) y su entrada en la matrix del CI; `tools/check-coherence.sh`
  avisará de que falta.

## `live-maker/*/usr/bin/void-installer` (22 ficheros)

- **Qué eran**: copias del instalador de Void, una por overlay (más una
  `.old` de una versión aún más vieja).
- **Por qué se borraron**: eran 10 *forks divergentes* del instalador de
  upstream (md5 `54b019…` frente al `77ae30…` original) y pisaban la copia
  que genera `mkiso.sh`, dejando además el `@@MKLIVE_VERSION@@` sin
  sustituir en el diálogo. Ahora hay **una** fuente:
  `live-maker/installer.sh`, que `neko-builder.sh` materializa en un overlay
  temporal con el token sustituido y pasa como `-I` adicional.
- **Cómo recuperarlos**: `git checkout 98c570b2 -- 'live-maker/*/usr/bin/void-installer'`
  — pero no conviene: volvería a introducir los forks.
