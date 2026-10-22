#!/bin/sh
# Verifica que la ISO lleva el instalador (fuente unica) y el PAM de autologin.
set -eu
ISO="$1"
echo "=== ISO: $ISO ==="
ls -la "$ISO"

echo
echo "=== 1. Volumen de la ISO ==="
xorriso -indev "$ISO" -pvd_info 2>/dev/null | grep -iE "volume id|boot" | head -5

echo
echo "=== 2. Extrayendo el squashfs del live ==="
rm -f /tmp/live.squashfs
xorriso -osirrox on -indev "$ISO" -extract /live/live.squashfs /tmp/live.squashfs 2>&1 | tail -2
ls -la /tmp/live.squashfs

echo
echo "=== 3. ¿Esta el instalador dentro? ==="
unsquashfs -l /tmp/live.squashfs 2>/dev/null | grep -E "void-installer" || echo "!!! NO HAY INSTALADOR !!!"

echo
echo "=== 4. Cabecera del instalador (¿@@MKLIVE_VERSION@@ sustituido?) ==="
unsquashfs -cat /tmp/live.squashfs usr/bin/void-installer 2>/dev/null | sed -n '95,102p'

echo
echo "=== 5. ¿Queda el token sin sustituir? ==="
if unsquashfs -cat /tmp/live.squashfs usr/bin/void-installer 2>/dev/null | grep -q "@@MKLIVE_VERSION@@"; then
	echo "!!! TOKEN SIN SUSTITUIR !!!"
else
	echo "OK: token sustituido"
fi

echo
echo "=== 6. Patch Neko presente (set_rice) ==="
unsquashfs -cat /tmp/live.squashfs usr/bin/void-installer 2>/dev/null | grep -n -A2 "^set_rice()" || echo "!!! falta set_rice !!!"

echo
echo "=== 7. PAM de autologin ==="
unsquashfs -cat /tmp/live.squashfs etc/pam.d/lightdm-autologin 2>/dev/null || echo "(sin PAM de lightdm en el live)"

echo
echo "=== 8. Fuentes de la ISO (el arbol de Limine) ==="
xorriso -indev "$ISO" -find / -name "limine*" 2>/dev/null | head -10

rm -f /tmp/live.squashfs
echo
echo "=== fin ==="
