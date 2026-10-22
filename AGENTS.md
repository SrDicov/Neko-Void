# AGENTS.md

ISO builder for Neko-Void Linux (Void-based live ISOs). No app code, no tests/lint/typecheck.

## Setup
- Submodules are empty on fresh clone and required (`kasha-installer`, `Neko-Wizard`, `neko-void-packages` pkgs):
  `git submodule update --init --recursive`

## Entrypoints (`live-maker/`)
- `neko-builder.sh` — only supported entry. Sources `base-neko-pkgs.sh` (`PACKAGES_*` vars) + `flavor.sh` (manifest reader), then calls `sudo ./mklive.sh` with hardcoded repos.
- `flavors/<name>` — the policy of each flavor (`key=value`): `desc`, `overlay`, `packages`, `kernel`, `dm`, `arch`, `iso`, and optional `overlay2`, `postsetup`, `extra`, `base=` (inheritance). The builder, the `--help` and the CI read the same manifest → a new flavor is a new file, not three coordinated edits.
- `flavor.sh` — the only manifest reader (`sh flavor.sh <flavor> <key>`; also usable as a library). Set `FLAVOR_DIR` when sourcing it from elsewhere.
- `mklive.sh` / `mkiso.sh` / `lib.sh` — upstream void-mklive, don't modify for Neko config; Neko config lives in `neko-builder.sh` + `base-neko-pkgs.sh` + `flavors/`.
- `neko-limine.sh` — Neko-only: runs `mklive.sh -K` and re-masters the ISO tree with Limine (BIOS+UEFI) instead of GRUB+isolinux. Template in `limine/limine.cfg.in`. Don't touch `mklive.sh` for this.
- `installer.sh` — the ONLY source of the installer. `mklive.sh` does not install it (only `mkiso.sh` does, and the builder does not use it), so `neko-builder.sh` materializes it in a temporary overlay with `@@MKLIVE_VERSION@@` substituted and passes it as an extra `-I`. Never vendor a copy in an overlay.
- `autologin/` — the ONLY source of the PAM file for LightDM autologin; the CI copies it to the flavor's overlay (`cp -n`: an overlay with its own variant, like `xfce/`, wins).
- Per-desktop overlay dirs: `mate/`, `kdedir/`, `xfce/`, `i3/`, `lxqt/`, `labwc/`, `niri/`, `icewm/`, `jwm/`, `musl/`. There is no `cinnamon/`/`lxde/` overlay and no such flavor.
- `labwc-musl/` is NOT a full overlay: only `etc/xbps.d/` (musl repos + z-repo-musl, empty files shadowing glibc `multilib`/`xlibre` confs) + `var/db/xbps/keys/zlinux-repo.pub`. The `labwc-musl` flavor passes `-I ./labwc -I ./labwc-musl` (mklive copies ALL the `-I`; the last one only wins for files with the same path).
- `tools/check-coherence.sh` — CI gate: manifests, builder, `--help` and CI matrix must talk about the same flavors, and every referenced path must exist. Run it after touching any of them.

## Build
- Requires privileged Void Linux (`ghcr.io/void-linux/void-glibc:20261001R1`) + `sudo`; never works on plain Ubuntu/host. Do not attempt locally, use CI. The host kernel must have the `loop` module (mklive builds the squashfs on a loop device); a kernel without it silently produces an empty squashfs.
- `cd live-maker && sudo bash neko-builder.sh <flavor> [-e "pkg1 pkg2"] [-b grub|limine]`
- Bootloader: `-b grub` (default, unchanged) or `-b limine` (Limine for BIOS+UEFI). The Limine variant suffixes the ISO name with `-limine` and adds the `limine` package to the live system.
- Valid `<flavor>` = the files in `live-maker/flavors/`: `i3 icewm jwm kde kde-nvidia labwc labwc-musl lxqt mate matelibre musl niri niri-nvidia nvidia nvidia-kde nvidia390 nvidia470 nvidia580 xfce`. `--help` and the interactive menu are generated from them, so they cannot go stale. `doble` is the only alias (mate + matelibre).
- `-r` repos are conditional on `$arch`: `*-musl` gets repo-ci musl + musl/nonfree + z-repo-musl; glibc keeps the old list. Never mix. The sourceforge musl repo is OUT of the musl list: it serves old builds (neko-themes 6.5_1) signed with a different key and xbps aborts on the unverified signature.
- The CI applies the autologin PAM (from `live-maker/autologin/`) and the generic permission/ownership steps to every flavor, driven by the manifest's `overlay` and `dm`. Only genuinely special flavors keep a `case` in the workflow (`xfce` downloads its config tarball, the nvidia ones add dracut modules, `labwc-musl` fetches the z-repo key).
- Root `README.md` build examples (`mate`/`matelibre` only) are partial; workflow matrix is the full list.
- The void-mklive image ships xbps 0.59.1, which CANNOT read Void's current (flat) repo index → every CI build failed at repo sync. Fixed by using `ghcr.io/void-linux/void-glibc:20261001R1` (monthly Void glibc image, xbps 0.60.7) + installing the host tools mklive needs (util-linux, e2fsprogs, dosfstools, shadow...). Local builds on the old image need the same xbps upgrade by hand.
- CI builds run via `docker run` (not `container:`): the JS actions of the runner need libstdc++ inside the container, and the Void glibc image has none. The xbps cache dir must stay owned by root inside the container, or xbps fails with EPERM changing the .xbps permissions.
- `live-maker/xbps-install-musl.sh` is the `XBPS_INSTALL_CMD` wrapper: xbps >= 0.60 ignores `XBPS_ARCH` when `-r` is used, so the musl target resolved nothing ("not found in repository pool"). The wrapper turns `-r` into `XBPS_ROOT`. It also drops the musl/aarch64 repos when the arch is not musl (mklive.sh:554 adds them always; a musl repo has no `x86_64-repodata`, so xbps fails the reposync).
- The CI MUST create the cachedir dirs before the symlinks (`mkdir -p /workspace/.cache/xbps/{target,host}`): with a cold cache the symlink dangles and xbps dies with `[trans] failed to change dir to cachedir ... No such file or directory` → "Failed to install required software".
- The glibc repo list must NOT contain musl repos (a musl repo has no `x86_64-repodata`; xbps aborts the whole sync). `tools/check-coherence.sh` watches that.

## CI / Artifacts
- GitHub `build-iso.yml`: manual dispatch only (`iso` choice + optional SourceForge upload), uploads to `arepaconcafe/untested-neko` HF dataset. GitLab `ci/build-{mate,xfce}.yml`: mate/xfce triggers.
- `live-maker/README.md`: generated (`make README.md`), do not edit. `*.iso` + `xbps-cachedir-*` are gitignored build outputs.
- **Puertas del CI** (todas antes del build, todas `sh tools/<algo>.sh`):
  - `check-coherence.sh`: manifests ↔ builder ↔ `--help` ↔ matrix del CI, y rutas existentes.
  - `check-workflows.sh`: el script del contenedor tiene que ser shell válido, su heredoc
    tiene que cerrar en la columna 0 y el `docker run` tiene que llevar `-i` (el script va
    por stdin). Sin `-i`, `sh -s` lee un script vacío: el contenedor sale con **0** y el
    build "pasa" sin generar la ISO.
  - `check-installer.sh`: todo comando destructivo de `installer.sh` comprueba su exit code.
  - `test-wrapper.sh`: el wrapper de xbps no filtra los repos musl del target.
- Un paso verde **no** significa que el build funcionó: si no hay ISO, el paso de
  checksums falla con "No se ha generado ninguna ISO" (no con un error de `sha256sum` vacío).
- Caches de GH: claves estables `xbps-labwc-musl-v2` y `xbps-iso-v2` (sin `hashFiles`).
  Las claves viejas con `hashFiles` se borraron (3,6 GB).
