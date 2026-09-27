# AGENTS.md

ISO builder for Neko-Void Linux (Void-based live ISOs). No app code, no tests/lint/typecheck.

## Setup
- Submodules are empty on fresh clone and required (`kasha-installer`, `Neko-Wizard`, `neko-void-packages` pkgs):
  `git submodule update --init --recursive`

## Entrypoints (`live-maker/`)
- `neko-builder.sh` — only supported entry. Sources `base-neko-pkgs.sh` (`PACKAGES_*` vars), then calls `sudo ./mklive.sh` with hardcoded repos.
- `mklive.sh` / `mkiso.sh` / `lib.sh` — upstream void-mklive, don't modify for Neko config; Neko config lives in `neko-builder.sh` + `base-neko-pkgs.sh`.
- Per-desktop overlay dirs: `mate/`, `kdedir/`, `xfce/`, `i3/`, `lxqt/`, `labwc/`, `niri/`, `icewm/`, `jwm/`, `musl/`. Missing `cinnamon/`/`lxde/` despite `case` entries — those targets are broken.
- `labwc-musl/` is NOT a full overlay: only `etc/xbps.d/` (musl repos + z-repo-musl, empty files shadowing glibc `multilib`/`xlibre` confs) + `var/db/xbps/keys/zlinux-repo.pub`. `neko-builder.sh labwc-musl` passes `-I ./labwc -I ./labwc-musl` (mklive allows multiple `-I`, last wins).

## Build
- Requires privileged Void Linux (`ghcr.io/void-linux/void-mklive:20250116R1`) + `sudo`; never works on plain Ubuntu/host. Do not attempt locally, use CI.
- `cd live-maker && sudo bash neko-builder.sh <desktop> [-e "pkg1 pkg2"]`
- Valid `<desktop>` = `case` labels in `build_iso()`: `mate matelibre kde lxqt i3 xfce icewm jwm cinnamon labwc labwc-musl niri musl nvidia nvidia-kde`. `--help` text and `interactive_menu()` still reference removed `xorg/xlibre/rolling/rollibre/doble*` names — stale, trust the `case`.
- `-r` repos are conditional on `$arch`: `*-musl` gets repo-ci musl + musl/nonfree + z-repo-musl + sourceforge musl (repo-ci is upstream's CI mirror, consistent); glibc keeps the old list. Never mix.
- Autologin/PAM/polkit overlay setup is NOT in the builder; each target needs its pre-steps from `.github/workflows/build-iso.yml` (matrix `case "$DESKTOP"`). Copy those blocks when adding a target.
- Root `README.md` build examples (`mate`/`matelibre` only) are partial; workflow matrix is the full list.

## CI / Artifacts
- GitHub `build-iso.yml`: manual dispatch only (`iso` choice + optional SourceForge upload), uploads to `arepaconcafe/untested-neko` HF dataset. GitLab `ci/build-{mate,xfce}.yml`: mate/xfce triggers.
- `live-maker/README.md`: generated (`make README.md`), do not edit. `*.iso` + `xbps-cachedir-*` are gitignored build outputs.
