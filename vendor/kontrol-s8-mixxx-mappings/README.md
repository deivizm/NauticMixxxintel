# Kontrol S8 mappings (vendored)

Copia sin modificar de los cuatro archivos de mapping de
[gusgustavodj/kontrol-s8-mixxx-mappings](https://github.com/gusgustavodj/kontrol-s8-mixxx-mappings)
(commit en `UPSTREAM_COMMIT`), GPL-2.0-or-later, autor gusgustavofreitas. Ver `LICENSE` y `NOTICE.md`.

Se instalan en `NauticMixxx.app/Contents/Resources/controllers` solo cuando se compila con
`RX3_WITH_S8=1`, junto con `patches-s8/0001-kontrol-s8-hid-display-on-nauticmixxx.patch`:
el parche original del autor (`patches-s8/upstream-*.patch.orig`, SHA-256
0800b7e1…cca6a, para Mixxx 3ebac449 = 2.5.6) adaptado sobre los 44 parches de NauticMixxx.

Adaptación: conflictos en `enginebuffer.cpp` combinados (estructura de emergencia USB de
NauticMixxx + comprobación de sample rate de los escaladores del parche S8); el cambio
`key_id` de `rekordboxfeature.cpp` se omite porque NauticMixxx ya no usa esa tabla.

Estado en macOS: el autor solo ha probado Windows. En macOS la pantalla usa libusb
(interfaz 6, endpoint 0x04) en lugar del driver de NI para Windows: sin probar en hardware.
