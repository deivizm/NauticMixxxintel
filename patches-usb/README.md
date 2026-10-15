# Fuentes de solo lectura: USB sin rekordbox, Traktor y rekordbox XML

`0001-folder-usb-sources-read-only.patch` se aplica después de los 44 parches de
NauticMixxx (y antes de `patches-s8/`, si se usa). Activo por defecto en la
compilación (`RX3_FOLDER_USB=1`).

## Qué aparece en SOURCE

| Fuente | Cómo se detecta | Navegación en el RX3 |
| --- | --- | --- |
| USB exportado con rekordbox | `PIONEER/rekordbox/export.pdb` (sin cambios) | Igual que antes |
| USB con playlists de Traktor (`.nml`) o un `rekordbox.xml` | Archivos `.nml`/`.xml` válidos hasta 2 carpetas de profundidad | ARTIST, ALBUM, TRACK, KEY, PLAYLIST, MATCHING, GENRE, BPM, RATING, FOLDER, SEARCH |
| USB con música normal | Volumen extraíble con audio compatible (búsqueda acotada) | FOLDER |
| Colección de Traktor del ordenador | Sin sandbox: el `collection.nml` más reciente de *Documents/Native Instruments/Traktor x.y.z*. En macOS (sandbox): con **ADD LIBRARY** | Igual que un USB con Traktor, sin FOLDER |
| rekordbox XML del ordenador | **ADD LIBRARY** (File › Export Collection in xml format) | Igual, sin FOLDER |

**ADD LIBRARY** es la última fila de SOURCE: abre el selector de archivos
(`.nml` / `.xml`). En macOS pide después la carpeta de la música (p. ej. *Música*)
para no pedir permiso pista a pista. Elegir otra vez un archivo ya añadido ofrece
quitarlo de SOURCE (el archivo no se toca).

## Abrir el navegador sin controladora compatible

- Botón **BROWSE** en la barra superior de la vista de decks.
- Botón **DECKS** en la cabecera del navegador para volver.
- **Cmd + B** (`[RX3Browser] toggle_view`, en todos los `res/keyboard/*.kbd.cfg`).

## Solo lectura

- Las pistas se cargan como temporales (`usbFolderPolicy`): no se guardan en la
  biblioteca de Mixxx, no se exportan metadatos y no se escribe nada en los archivos.
  Mixxx las analiza en memoria para la forma de onda.
- Se importan título, artista, álbum, género, año, key, rating, **hot cues, memory
  cues, loops y la rejilla** de la biblioteca (Traktor: marcador de grid + BPM;
  rekordbox XML: `TEMPO`, con tempo variable si lo hay).
- `setReadOnlySourceRoot` marca cada USB y cada archivo de biblioteca: los puntos de
  escritura de Mixxx (`isReadOnlyPath`) y los escritores de NauticMixxx (MY SETTINGS,
  color, playlists/historial, rating, grabación) los rechazan. La sesión externa
  devuelve "This library is read-only in NauticMixxx." a cualquier escritura.
- Desconectar uno de estos USB mientras suena expulsa la pista de ese deck (el bucle
  de emergencia es solo para USB rekordbox).

## Ajustes (`mixxx.cfg`, grupo `[Library]`)

- `FolderUsbSources 0` oculta los USB sin rekordbox.
- `ExternalLibrarySources 0` oculta Traktor / rekordbox XML y ADD LIBRARY.

## Pruebas

- `Rx3FolderUsbTest.*`: límites de solo lectura y búsqueda acotada.
- `Rx3ExternalCatalogTest.*`: lector NML/XML (cues, rejillas, playlists, rutas, USB).
- `Rx3ExternalTrackTest.*`: sesión externa, pistas temporales, escrituras rechazadas,
  archivos intactos (hash antes/después).
