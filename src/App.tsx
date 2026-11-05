import { useEffect, useState, useCallback } from 'react';
import {
  Music,
  Search,
  Radio,
  Clock,
  Shuffle,
  Flame,
  Sparkles,
  SlidersHorizontal,
  Settings,
  Battery,
  Wifi,
  Play,
  Square,
  SkipForward,
  ChevronRight,
  BookOpen,
} from 'lucide-react';
import { JukeboxPlaylist, RadioStation, ServerConfig, Song, ToastMessage } from './types';
import { subsonicService } from './services/subsonic';
import { PlayerDialog } from './components/PlayerDialog';
import { QuickControlsModal } from './components/QuickControlsModal';
import { SearchDialog } from './components/SearchDialog';
import { RadiosModal } from './components/RadiosModal';
import { AlbumModal } from './components/AlbumModal';
import { ArtistModal } from './components/ArtistModal';
import { AlbumListModal } from './components/AlbumListModal';
import { ArtistListModal } from './components/ArtistListModal';
import { QueueModal } from './components/QueueModal';
import { ConfigModal } from './components/ConfigModal';
import { Toast } from './components/Toast';

export function App() {
  const [config, setConfig] = useState<ServerConfig>(() => subsonicService.getConfig());
  const [playlist, setPlaylist] = useState<JukeboxPlaylist | null>(null);
  const [isLoadingPlayer, setIsLoadingPlayer] = useState(false);
  const [toasts, setToasts] = useState<ToastMessage[]>([]);

  // Modals state
  const [activeModal, setActiveModal] = useState<
    'player' | 'search' | 'radios' | 'quick' | 'config' | 'queue' | 'recent' | 'random' | 'top' | 'discover' | null
  >('player'); // Replicates opening PlayerDialog initially

  const [selectedAlbum, setSelectedAlbum] = useState<{ id: string; title: string } | null>(null);
  const [selectedArtist, setSelectedArtist] = useState<{ id: string; name: string } | null>(null);

  const addToast = useCallback((text: string, type: 'info' | 'error' | 'success' = 'info') => {
    setToasts((prev) => [...prev, { id: Math.random().toString(), text, type }]);
  }, []);

  const refreshNowPlaying = useCallback(async () => {
    setIsLoadingPlayer(true);
    const { playlist: updated, error } = await subsonicService.getNowPlaying();
    setIsLoadingPlayer(false);
    if (error) {
      addToast(error, 'error');
    } else if (updated) {
      setPlaylist(updated);
    }
  }, [addToast]);

  useEffect(() => {
    refreshNowPlaying();
  }, [refreshNowPlaying]);

  const handleSaveConfig = (newConfig: ServerConfig) => {
    const saved = subsonicService.saveConfig(newConfig);
    setConfig(saved);
    addToast('Configuración guardada correctamente.', 'success');
    refreshNowPlaying();
  };

  // Play songs handler
  const handlePlaySongs = async (ids: string[], label: string) => {
    const res = await subsonicService.playSongs(ids);
    if (res.success) {
      addToast(`Reproduciendo ahora:\n${label}`, 'success');
      refreshNowPlaying();
      setActiveModal('player');
    } else {
      addToast(res.error || 'Error al reproducir', 'error');
    }
  };

  // Add songs handler
  const handleAddSongs = async (ids: string[], label: string) => {
    const res = await subsonicService.addSongs(ids);
    if (res.success) {
      addToast(`Añadido a la cola:\n${label}`, 'success');
      refreshNowPlaying();
    } else {
      addToast(res.error || 'Error al añadir', 'error');
    }
  };

  // Play radio handler
  const handlePlayRadio = async (station: RadioStation) => {
    const res = await subsonicService.playRadio(station);
    if (res.success) {
      addToast(`Reproduciendo radio:\n${station.name}`, 'success');
      refreshNowPlaying();
      setActiveModal('player');
    } else {
      addToast(res.error || 'Error al reproducir radio', 'error');
    }
  };

  // Add radio handler
  const handleAddRadio = async (station: RadioStation) => {
    const res = await subsonicService.addRadio(station);
    if (res.success) {
      addToast(`Radio añadida a la cola:\n${station.name}`, 'success');
      refreshNowPlaying();
    } else {
      addToast(res.error || 'Error al añadir radio', 'error');
    }
  };

  const currentSong: Song | null =
    playlist && playlist.currentIndex >= 0 && playlist.currentIndex < playlist.entry.length
      ? playlist.entry[playlist.currentIndex]
      : null;

  // Menu items list matching main.lua lines 582-594
  const menuItems = [
    {
      id: 'player',
      icon: Music,
      label: 'Reproductor (Now Playing)',
      action: () => setActiveModal('player'),
      desc: currentSong ? `Sonando: ${currentSong.title}` : 'Consultar o controlar la pista activa',
    },
    {
      id: 'search',
      icon: Search,
      label: 'Buscar música',
      action: () => setActiveModal('search'),
      desc: 'Búsqueda por artista, álbum o canción',
    },
    {
      id: 'radios',
      icon: Radio,
      label: 'Radios de Navidrome',
      action: () => setActiveModal('radios'),
      desc: 'Emisoras de radio por internet en directo',
    },
    {
      id: 'recent',
      icon: Clock,
      label: 'Álbumes recién añadidos',
      action: () => setActiveModal('recent'),
      desc: 'Últimas novedades agregadas a la biblioteca',
    },
    {
      id: 'random',
      icon: Shuffle,
      label: 'Álbumes aleatorios',
      action: () => setActiveModal('random'),
      desc: 'Selección al azar de discos de tu servidor',
    },
    {
      id: 'top',
      icon: Flame,
      label: 'Artistas más escuchados',
      action: () => setActiveModal('top'),
      desc: 'Agrupados por número de reproducciones',
    },
    {
      id: 'discover',
      icon: Sparkles,
      label: 'Descubre artistas',
      action: () => setActiveModal('discover'),
      desc: 'Selección aleatoria de tu catálogo',
    },
    {
      id: 'quick',
      icon: SlidersHorizontal,
      label: 'Controles rápidos del Jukebox',
      action: () => setActiveModal('quick'),
      desc: 'Detener, reanudar, pasar pista o vaciar cola',
    },
    {
      id: 'config',
      icon: Settings,
      label: 'Configurar servidor y cuenta',
      action: () => setActiveModal('config'),
      desc: config.url ? `Servidor: ${config.url}` : 'Introduce URL, usuario y contraseña de Navidrome',
    },
  ];

  return (
    <div className="min-h-screen flex flex-col justify-between eink-mode bg-[#f6f5f0] text-black">
      {/* Kindle / KOReader Viewport Frame */}
      <div className="w-full max-w-2xl mx-auto flex-1 flex flex-col p-2 sm:p-5">
        <div className="flex-1 flex flex-col overflow-hidden bg-white border-4 border-black shadow-[6px_6px_0px_#000000]">
          {/* Top Status Bar (Authentic KOReader E-Reader Look) */}
          <header className="flex items-center justify-between px-4 py-2 border-b-2 border-black bg-stone-100 text-xs font-mono select-none text-black">
            <div className="flex items-center gap-2 truncate pr-2">
              <BookOpen className="w-3.5 h-3.5 shrink-0" />
              <span className="font-bold tracking-tight shrink-0">KOReader</span>
              <span className="opacity-50">/</span>
              <span className="truncate">
                {currentSong ? `♪ ${currentSong.title}` : 'Navidrome Jukebox'}
              </span>
            </div>

            <div className="flex items-center gap-3 shrink-0">
              <Wifi className="w-3.5 h-3.5" />
              <div className="flex items-center gap-1 font-semibold">
                <span>95%</span>
                <Battery className="w-3.5 h-3.5" />
              </div>
            </div>
          </header>

          {/* Plugin Title & Quick Navigation */}
          <div className="p-4 border-b-2 border-black bg-stone-50 flex items-center justify-between gap-3">
            <div>
              <div className="flex items-center gap-2">
                <Music className="w-5 h-5 text-black" />
                <h1 className="text-xl font-bold tracking-tight">Navidrome Jukebox</h1>
              </div>
              <p className="text-xs text-stone-600 mt-0.5">
                Control del jukebox de Navidrome (Subsonic API)
              </p>
            </div>

            <button
              onClick={() => setActiveModal('config')}
              className="text-xs px-3 py-1.5 flex items-center gap-1.5 font-bold border-2 border-black bg-white hover:bg-stone-100 shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5"
            >
              <Settings className="w-3.5 h-3.5" />
              <span>Ajustes</span>
            </button>
          </div>

          {/* Main KOReader Menu Items Table */}
          <main className="flex-1 overflow-y-auto p-2 sm:p-3 divide-y divide-stone-200">
            {menuItems.map((item) => {
              const Icon = item.icon;
              return (
                <button
                  key={item.id}
                  onClick={item.action}
                  className="w-full flex items-center justify-between p-3.5 text-left hover:bg-stone-100 active:bg-stone-200 text-black transition select-none"
                >
                  <div className="flex items-center gap-3.5 truncate pr-2">
                    <div className="w-10 h-10 flex items-center justify-center shrink-0 border-2 border-black bg-white shadow-[2px_2px_0px_#000]">
                      <Icon className="w-5 h-5 fill-current" />
                    </div>

                    <div className="truncate">
                      <div className="font-bold text-sm sm:text-base leading-snug">
                        {item.label}
                      </div>
                      <div className="text-xs text-stone-600 truncate mt-0.5">{item.desc}</div>
                    </div>
                  </div>

                  <ChevronRight className="w-5 h-5 text-black shrink-0" />
                </button>
              );
            })}
          </main>

          {/* Bottom Mini Player Dock */}
          <footer
            onClick={() => setActiveModal('player')}
            className="p-3 border-t-2 border-black cursor-pointer flex items-center justify-between gap-3 bg-stone-100 hover:bg-stone-200 text-black select-none"
          >
            <div className="flex items-center gap-3 truncate min-w-0">
              <div className="w-10 h-10 flex items-center justify-center shrink-0 border-2 border-black bg-white">
                {currentSong?.isRadio ? <Radio className="w-5 h-5" /> : <Music className="w-5 h-5" />}
              </div>

              <div className="truncate">
                <div className="font-bold text-xs sm:text-sm truncate">
                  {currentSong ? currentSong.title : 'Nada en reproducción'}
                </div>
                <div className="text-xs text-stone-600 truncate">
                  {currentSong
                    ? currentSong.isRadio
                      ? 'Emisora de Radio en directo'
                      : `${currentSong.artist} — ${currentSong.album}`
                    : 'Toca para abrir el reproductor'}
                </div>
              </div>
            </div>

            <div
              className="flex items-center gap-2 shrink-0"
              onClick={(e) => e.stopPropagation()}
            >
              <button
                onClick={async () => {
                  await subsonicService.togglePlayback(playlist?.playing ?? false);
                  refreshNowPlaying();
                }}
                className="p-2 bg-black text-white border-2 border-black active:translate-x-0.5 active:translate-y-0.5"
                title={playlist?.playing ? 'Detener' : 'Reproducir'}
              >
                {playlist?.playing ? (
                  <Square className="w-4 h-4 fill-current" />
                ) : (
                  <Play className="w-4 h-4 fill-current ml-0.5" />
                )}
              </button>

              <button
                onClick={async () => {
                  await subsonicService.skip(
                    1,
                    playlist?.currentIndex ?? 0,
                    playlist?.entry.length ?? 0
                  );
                  refreshNowPlaying();
                }}
                className="p-2 bg-white border-2 border-black text-black active:translate-x-0.5 active:translate-y-0.5"
                title="Siguiente pista"
              >
                <SkipForward className="w-4 h-4 fill-current" />
              </button>
            </div>
          </footer>
        </div>
      </div>

      {/* Modals */}
      {activeModal === 'player' && (
        <PlayerDialog
          playlist={playlist}
          isLoading={isLoadingPlayer}
          onClose={() => setActiveModal(null)}
          onRefresh={refreshNowPlaying}
          onOpenQueue={() => setActiveModal('queue')}
          onTriggerRefreshEffect={() => {}}
          isEink={true}
        />
      )}

      {activeModal === 'radios' && (
        <RadiosModal
          onClose={() => setActiveModal(null)}
          onPlayRadio={handlePlayRadio}
          onAddRadio={handleAddRadio}
          onNotify={addToast}
        />
      )}

      {activeModal === 'quick' && (
        <QuickControlsModal
          onClose={() => setActiveModal(null)}
          onRefresh={refreshNowPlaying}
          onNotify={(msg) => addToast(msg)}
          onTriggerRefreshEffect={() => {}}
          isEink={true}
        />
      )}

      {activeModal === 'search' && (
        <SearchDialog
          onClose={() => setActiveModal(null)}
          onSelectArtist={(id, name) => setSelectedArtist({ id, name })}
          onSelectAlbum={(id, title) => setSelectedAlbum({ id, title })}
          onPlaySong={(song) => handlePlaySongs([song.id], song.title)}
          onAddSong={(song) => handleAddSongs([song.id], song.title)}
          onTriggerRefreshEffect={() => {}}
          isEink={true}
        />
      )}

      {activeModal === 'recent' && (
        <AlbumListModal
          title="Álbumes recién añadidos"
          listType="newest"
          onClose={() => setActiveModal(null)}
          onSelectAlbum={(id, title) => setSelectedAlbum({ id, title })}
          onTriggerRefreshEffect={() => {}}
          isEink={true}
        />
      )}

      {activeModal === 'random' && (
        <AlbumListModal
          title="Álbumes aleatorios"
          listType="random"
          onClose={() => setActiveModal(null)}
          onSelectAlbum={(id, title) => setSelectedAlbum({ id, title })}
          onTriggerRefreshEffect={() => {}}
          isEink={true}
        />
      )}

      {activeModal === 'top' && (
        <ArtistListModal
          title="Artistas más escuchados"
          mode="top"
          onClose={() => setActiveModal(null)}
          onSelectArtist={(id, name) => setSelectedArtist({ id, name })}
          onTriggerRefreshEffect={() => {}}
          isEink={true}
        />
      )}

      {activeModal === 'discover' && (
        <ArtistListModal
          title="Descubre artistas (selección aleatoria)"
          mode="discover"
          onClose={() => setActiveModal(null)}
          onSelectArtist={(id, name) => setSelectedArtist({ id, name })}
          onTriggerRefreshEffect={() => {}}
          isEink={true}
        />
      )}

      {activeModal === 'queue' && (
        <QueueModal
          playlist={playlist}
          onClose={() => setActiveModal(null)}
          onRefresh={refreshNowPlaying}
          onTriggerRefreshEffect={() => {}}
          isEink={true}
        />
      )}

      {activeModal === 'config' && (
        <ConfigModal
          currentConfig={config}
          onClose={() => setActiveModal(null)}
          onSave={handleSaveConfig}
        />
      )}

      {/* Nested drilldown modals */}
      {selectedAlbum && (
        <AlbumModal
          albumId={selectedAlbum.id}
          albumTitle={selectedAlbum.title}
          onClose={() => setSelectedAlbum(null)}
          onPlaySongs={handlePlaySongs}
          onAddSongs={handleAddSongs}
          onTriggerRefreshEffect={() => {}}
          isEink={true}
        />
      )}

      {selectedArtist && (
        <ArtistModal
          artistId={selectedArtist.id}
          artistName={selectedArtist.name}
          onClose={() => setSelectedArtist(null)}
          onSelectAlbum={(id, title) => setSelectedAlbum({ id, title })}
          onTriggerRefreshEffect={() => {}}
          isEink={true}
        />
      )}

      {/* KOReader InfoMessage Toasts */}
      <Toast toasts={toasts} onDismiss={(id) => setToasts((t) => t.filter((x) => x.id !== id))} isEink={true} />
    </div>
  );
}
export default App;
