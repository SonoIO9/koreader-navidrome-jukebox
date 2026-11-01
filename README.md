# Navidrome Jukebox — plugin de KOReader

Controla un servidor [Navidrome](https://www.navidrome.org/) (API Subsonic) desde KOReader:
explora tu biblioteca, busca música y maneja la cola de reproducción del jukebox.

## Funciones

- **Reproductor (Now Playing)**: carátula, título/artista/álbum y controles
  (anterior, play/stop, siguiente, aleatorio, recargar, cerrar).
- **Buscar música** por artista, álbum o canción.
- **Álbumes recién añadidos** y **álbumes aleatorios**.
- **Artistas más escuchados** (aproximado, agrupando por `playCount`).
- **Descubre artistas**: selección aleatoria de tu biblioteca.
- **Controles rápidos del jukebox**: detener, reanudar, siguiente, vaciar cola.
- Caché de carátulas en disco.

## Instalación

1. Copia la carpeta `navidrome.koplugin` a la carpeta de plugins de KOReader:
   - KOReader: `koreader/plugins/`
2. Reinicia KOReader.
3. Abre el menú **Herramientas → Navidrome Jukebox**.
4. Entra en **Configurar servidor y cuenta** e introduce:
   - la URL del servidor (por ejemplo `https://musica.ejemplo.com`),
   - el usuario,
   - la contraseña.
5. Prueba la conexión desde **Buscar música**.

## Notas técnicas

- Los iconos usan glifos FontAwesome de la fuente Nerd Font que KOReader
  incluye siempre en su cadena de fuentes de reserva
  (`resources/fonts/nerdfonts/symbols.ttf`). Los emoji a color no están en
  ninguna fuente que KOReader empaquete, por eso no se usan.
- El diálogo del reproductor es un `InputContainer` modal: consume los toques
  que no van a un botón y repinta lo que queda debajo al cerrarse.
- El reproductor se muestra al instante y las peticiones de red se difieren al
  siguiente tick de la interfaz, para que la pantalla no parezca colgada.

## Licencia

MIT
