# Neko-Void ISO Builder

![image](https://huggingface.co/arepaconcafe/neko-base/resolve/main/1.png)

This repository allows you to build custom Live ISO images for Neko-Void Linux. The build process includes support for non-free software, proprietary drivers, Steam, and gaming-related packages.

## Cloning the Repository

First, clone this repository and its submodules. This repository includes the source code for the Neko Wizard and the Kasha installer module.

```bash
git clone https://github.com/Neko-Void-Linux/Neko-Void.git Neko-Void
cd Neko-Void
git submodule update --init --recursive

```
## Build Instructions
To build a Neko-Void ISO, you need to use the neko-builder.sh script located in the live-maker directory. First, change to that directory:
```bash
cd live-maker

```
Then, execute the builder script with your desired configuration:
### Standard Builds
 * **Build Xorg ISO:**
   ```bash
   bash neko-builder.sh mate
   
   ```
 * **Build Xlibre ISO:**
   ```bash
   bash neko-builder.sh matelibre
   
   ```
 * **Build ISO with Limine instead of GRUB (BIOS + UEFI, dualboot):**
   ```bash
   bash neko-builder.sh labwc -b limine
   
   ```

## neko-builder.sh Usage Details
The build script supports multiple options. For example:
 * ./neko-builder.sh - Runs in interactive mode.
 * ./neko-builder.sh <flavor> - Builds a specific desktop environment (e.g., mate, matelibre, kde).
 * ./neko-builder.sh <flavor> -e "pkg..." - Builds with extra specified packages.
 * ./neko-builder.sh <flavor> -b grub|limine - Chooses the ISO bootloader: `grub` (default, GRUB for UEFI + isolinux for BIOS) or `limine` (Limine for both BIOS and UEFI, with chainload entries for Windows/other Linux).
 * ./neko-builder.sh doble - Builds both the Xlibre (matelibre) and Xorg (mate) ISOs.

### Flavors
A flavor is a file in `live-maker/flavors/<name>` with `key=value` lines:

```
desc=MATE + Xorg (kernel mainline)
overlay=mate
packages=PACKAGES_XORG
kernel=linux-mainline
dm=lightdm
arch=x86_64
iso=nekovoid-mate
```

The builder, the `--help` and the CI read the same manifest (`live-maker/flavor.sh`), so
adding a flavor means adding one file. `base=<flavor>` inherits the missing keys.

### Coherence check
`sh tools/check-coherence.sh` verifies that the manifests, the builder, the `--help`
and the CI matrix talk about the same flavors and that every referenced path exists.
It runs in CI before the build.

## Related Projects and Resources
You can find more information about the Neko ecosystem at these locations:
 * **Repo Builder:** https://github.com/Neko-Void-Linux/repo-neko
 * **Custom Kernels (Actions):** https://github.com/Neko-Void-Linux/kernel-neko-void/actions
 * **Website Source Code:** https://github.com/javiercplus/nk-web
