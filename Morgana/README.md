# Morgana (iOS)

Reproductor de música local y privado para iOS, al estilo Apple Music: biblioteca por canciones, álbumes y artistas, carátulas, reproducción en segundo plano y controles en la pantalla de bloqueo. Sin cuentas, sin nube, sin anuncios.

## Qué hace

- Añades una o varias carpetas (de "En mi iPhone", iCloud Drive u otro proveedor de Archivos) y la app escanea los `.flac` que haya dentro, subcarpetas incluidas.
- Los archivos **no se copian**: se leen desde su carpeta. Se guarda un acceso persistente a ella.
- Lee etiquetas Vorbis (título, artista, artista del álbum, álbum, año, pista, disco), la carátula incrustada y los datos técnicos (frecuencia y profundidad de bits).
- Pestañas: Inicio (buscador y acceso rápido a Canciones, Favoritos, Géneros y Listas), Álbumes, Artistas y Configuración (carpetas y estadísticas).
- Favoritos con estrella (en Now Playing, deslizando una fila o con pulsación larga) y listas de reproducción propias: crear, renombrar, reordenar, quitar canciones y eliminar. Los géneros salen de la etiqueta GENRE de los FLAC.
- Mini reproductor y pantalla de reproducción con fondo dinámico según la carátula, modo apaisado en dos columnas, aleatorio real, repetición (off / todo / una), tarjetas con códec, frecuencia, profundidad y bitrate, y texto deslizante en títulos largos.
- Controles de la pantalla de bloqueo.
- Géneros: al entrar se puede agrupar por canción o por álbum, y el menú ⋯ añade todo el género a favoritos (un toque) o a una lista concreta.
- Etiquetas múltiples: ARTIST, ALBUMARTIST y GENRE pueden repetirse o venir separadas por «;». Un álbum con varios artistas aparece bajo cada uno. No se separa por «/» ni «,» para no romper nombres como AC/DC.
- Letra incrustada (LYRICS o UNSYNCEDLYRICS): botón **Letra** en Now Playing cuando la pista la tiene. Las marcas de tiempo de letras sincronizadas (LRC) se ocultan. Tras actualizar, pulsa **Volver a escanear** para que se detecten.
- El escaneo procesa los archivos por lotes y libera memoria entre archivos, para bibliotecas grandes (más de 1 500 pistas).

Fuera de esta versión: ecualizador, gapless garantizado, CarPlay y otros formatos.

## Compilar sin Mac (gratis)

1. Crea un repositorio en GitHub (si es **público**, los minutos de macOS son gratuitos) y sube el contenido de esta carpeta.
2. En la pestaña **Actions** se ejecuta el workflow **Build IPA** en cada push a `main`. También puedes lanzarlo a mano con *Run workflow*.
3. Cuando termine, descarga el artefacto **Morgana-ipa** y descomprímelo para obtener `Morgana.ipa` (sin firmar).

El proyecto de Xcode se genera en el propio workflow a partir de `project.yml` con [XcodeGen](https://github.com/yonaskolb/XcodeGen); por eso no hay `.xcodeproj` en el repositorio.

## Instalar en el iPhone desde Windows

1. Instala [Sideloadly](https://sideloadly.io) (o AltStore). Necesitan iTunes e iCloud descargados de la web de Apple, no de la Microsoft Store.
2. Conecta el iPhone por USB, arrastra `Morgana.ipa` a Sideloadly, escribe tu Apple ID y pulsa *Start*.
3. En iOS 16 o superior activa el **Modo de desarrollador**: Ajustes → Privacidad y seguridad → Modo de desarrollador.
4. Ajustes → General → VPN y gestión de dispositivos → confía en tu Apple ID.

Con un Apple ID gratuito la firma **caduca a los 7 días** y hay un máximo de 3 apps instaladas así. Sideloadly o AltStore pueden refrescarla; si caduca, vuelve a instalar el `.ipa`.

## Uso

1. Abre la app → pestaña **Configuración** → **Añadir carpeta** y elige donde tienes los FLAC.
2. Espera al escaneo. La biblioteca aparece en el resto de pestañas.
3. Si añades música nueva, usa **Volver a escanear**.

Si los archivos están en iCloud Drive, márcalos como descargados (*Mantener descargado*); los archivos que solo están en la nube no se pueden leer.

## Estructura

```
project.yml                      Configuración de XcodeGen (target, Info.plist, audio en segundo plano)
.github/workflows/build.yml      Compila y genera el .ipa
Morgana/
  MorganaApp.swift           Punto de entrada
  Models/Models.swift            Track, Album, Artist, utilidades
  Services/FLACParser.swift      Lector de metadatos FLAC (STREAMINFO, VORBIS_COMMENT, PICTURE)
  Services/LibraryScanner.swift  Recorre carpetas y crea las pistas
  Services/LibraryStore.swift    Biblioteca, carpetas con acceso persistente, índices, guardado en JSON
  Services/ArtworkStore.swift    Carátulas en disco y miniaturas
  Services/PlayerManager.swift   AVPlayer, cola, Now Playing y controles remotos
  Views/                         Interfaz SwiftUI
```

## Estado

Este código se escribió sin poder compilarlo localmente, así que **el primer build en GitHub Actions puede fallar** por algún detalle del compilador. Si pasa, copia el error del log y se corrige.
