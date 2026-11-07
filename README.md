# Navidrome Jukebox — plugin de KOReader

Controla un servidor [Navidrome](https://www.navidrome.org/) (API Subsonic) desde KOReader:
explora tu biblioteca, busca música y maneja la cola de reproducción del jukebox.

<img width="595" height="802" alt="imagen" src="https://github.com/user-attachments/assets/8482e23d-d02c-4cad-ac14-c2d7255a414d" />


## Funciones

- **Reproductor (Now Playing)**: carátula, título/artista/álbum y controles
  (anterior, play/stop, siguiente, aleatorio, recargar, cerrar).
- **Buscar música** por artista, álbum o canción.
- **Listas de Navidrome**: explora y reproduce tus listas.
- **Álbumes recién añadidos** y **álbumes aleatorios**.
- **Artistas más escuchados** (aproximado, agrupando por `playCount`).
- **Descubre artistas**: selección aleatoria de tu biblioteca.
- **Letra**: Muestra las letras de la canción que se está reproduciendo.
- **Configurar servidor y cuenta**: guarda tus datos de acceso localmente con prueba de conexión integrada.
- Caché de carátulas en disco.

## Instalación

1. Copia la carpeta `navidrome.koplugin` a la carpeta de plugins de KOReader:
   - KOReader: `koreader/plugins/`
2. Reinicia KOReader.
3. Abre el menú **Herramientas → Navidrome Jukebox**.
4. Entra en **Configurar servidor y cuenta**:
   - Introduce la URL del servidor (por ejemplo `http://192.168.1.100:4533` o `https://musica.ejemplo.com`),
   - Introduce el usuario,
   - Introduce la contraseña,
   - Pulsa **Probar conexión ahora** para verificar la conexión al instante.

## Licencia

MIT
