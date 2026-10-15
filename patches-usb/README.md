# USB sin rekordbox (solo lectura)

`0001-folder-usb-sources-read-only.patch` se aplica después de los 44 parches de
NauticMixxx (y antes de `patches-s8/`, si se usa). Activo por defecto en la
compilación (`RX3_FOLDER_USB=1`) y en tiempo de ejecución
(`[Library] FolderUsbSources 1`; poner `0` en `mixxx.cfg` lo desactiva).

- SOURCE lista también los USB sin `PIONEER/rekordbox/export.pdb`. Se navegan solo
  por **FOLDER**; SEARCH, PLAYLIST, historial, MY SETTINGS, color, grabación y
  rating no están disponibles para ellos.
- Las pistas se cargan como temporales (`usbFolderPolicy`): se analizan en memoria
  para forma de onda/BPM, no se guardan en la biblioteca y nunca se escribe nada en
  el USB (`setFolderOnlyRoot` protege la raíz en todos los puntos de escritura, y
  los escritores de rekordbox la rechazan además explícitamente).
- macOS: igual que con rekordbox, la primera vez se pide permiso de lectura con el
  diálogo del sistema. Windows/Linux: solo se listan volúmenes que no son el
  sistema ni el de usuario y que contienen audio compatible (búsqueda acotada).
- Desconectar uno de estos USB mientras suena expulsa la pista de ese deck (el bucle
  de emergencia solo existe para USB rekordbox).

Pruebas: `src/test/rx3folderusb_test.cpp` (`Rx3FolderUsbTest.*`).
