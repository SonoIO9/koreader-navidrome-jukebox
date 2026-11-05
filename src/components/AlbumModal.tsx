import React, { useEffect, useState } from 'react';
import { Disc, Play, Plus, Image as ImageIcon, X } from 'lucide-react';
import { subsonicService } from '../services/subsonic';
import { Album, Song } from '../types';

interface AlbumModalProps {
  albumId: string;
  albumTitle: string;
  onClose: () => void;
  onPlaySongs: (ids: string[], label: string) => void;
  onAddSongs: (ids: string[], label: string) => void;
  onTriggerRefreshEffect: () => void;
  isEink: boolean;
}

export const AlbumModal: React.FC<AlbumModalProps> = ({
  albumId,
  albumTitle,
  onClose,
  onPlaySongs,
  onAddSongs,
  onTriggerRefreshEffect,
  isEink,
}) => {
  const [album, setAlbum] = useState<Album | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [showFullCover, setShowFullCover] = useState(false);

  useEffect(() => {
    let isMounted = true;
    async function loadAlbum() {
      setIsLoading(true);
      const { data } = await subsonicService.apiRequest('getAlbum.view', { id: albumId });
      if (isMounted) {
        if (data?.album) {
          const songs = Array.isArray(data.album.song)
            ? data.album.song
            : data.album.song
            ? [data.album.song]
            : [];
          setAlbum({ ...data.album, song: songs });
        }
        setIsLoading(false);
      }
    }
    loadAlbum();
    return () => {
      isMounted = false;
    };
  }, [albumId]);

  const songs: Song[] = album?.song || [];
  const playableIds = songs.map((s) => s.id);
  const coverUrl = album ? subsonicService.getCoverArtUrl(album.coverArt || album.id, 600) : '';

  const formatDuration = (seconds?: number) => {
    if (!seconds) return '';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  };

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-3 bg-black/60 backdrop-blur-xs">
      <div
        className={`w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden ${
          isEink
            ? 'bg-white text-black border-4 border-black shadow-[6px_6px_0px_#000]'
            : 'bg-stone-900 text-stone-100 rounded-2xl border border-stone-800 shadow-2xl'
        }`}
      >
        {/* Header */}
        <div
          className={`flex items-center justify-between px-4 py-3 border-b ${
            isEink ? 'border-black bg-stone-100 font-bold' : 'border-stone-800 bg-stone-950 font-semibold'
          }`}
        >
          <span className="flex items-center gap-2 truncate">
            <Disc className="w-4 h-4 shrink-0" />
            <span className="truncate">Álbum: {albumTitle}</span>
          </span>
          <button onClick={onClose} className="p-1 hover:opacity-70">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Scrollable content */}
        <div className="flex-1 overflow-y-auto p-4">
          {isLoading ? (
            <div className="py-12 text-center text-sm text-stone-500">
              Cargando álbum desde Navidrome...
            </div>
          ) : (
            <div className="space-y-4">
              {/* Album Hero Info */}
              <div className="flex gap-4 items-start">
                {coverUrl ? (
                  <img
                    src={coverUrl}
                    alt={albumTitle}
                    onClick={() => setShowFullCover(true)}
                    className={`w-24 h-24 object-cover cursor-pointer hover:opacity-90 transition shrink-0 ${
                      isEink ? 'border-2 border-black grayscale contrast-125' : 'rounded-lg border border-stone-800'
                    }`}
                  />
                ) : (
                  <div
                    className={`w-24 h-24 flex items-center justify-center shrink-0 ${
                      isEink ? 'border-2 border-black bg-stone-100' : 'bg-stone-950 rounded-lg border border-stone-800'
                    }`}
                  >
                    <Disc className="w-8 h-8 text-stone-400" />
                  </div>
                )}

                <div className="flex-1 min-w-0">
                  <h3 className="font-bold text-lg leading-tight truncate">{album?.name || albumTitle}</h3>
                  <p className="text-sm text-stone-500 mt-0.5 truncate">{album?.artist || 'Artista'}</p>
                  {album?.year && (
                    <p className="text-xs text-stone-400 mt-1">Año: {album.year}</p>
                  )}
                  {songs.length > 0 && (
                    <p className="text-xs text-stone-400 mt-0.5">
                      {songs.length} canciones
                    </p>
                  )}
                </div>
              </div>

              {/* Action buttons (Ver portada, Reproducir, Añadir) */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 pt-1">
                {coverUrl && (
                  <button
                    onClick={() => setShowFullCover(true)}
                    className={`flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-semibold transition ${
                      isEink
                        ? 'bg-white border-2 border-black shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                        : 'bg-stone-800 hover:bg-stone-700 text-stone-200 rounded-lg'
                    }`}
                  >
                    <ImageIcon className="w-3.5 h-3.5" />
                    Ver portada
                  </button>
                )}

                <button
                  disabled={playableIds.length === 0}
                  onClick={() => {
                    onTriggerRefreshEffect();
                    onPlaySongs(playableIds, albumTitle);
                  }}
                  className={`flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-semibold transition disabled:opacity-40 ${
                    isEink
                      ? 'bg-black text-white border-2 border-black shadow-[2px_2px_0px_#555] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                      : 'bg-white text-black hover:bg-stone-200 rounded-lg'
                  }`}
                >
                  <Play className="w-3.5 h-3.5 fill-current ml-0.5" />
                  Reproducir álbum
                </button>

                <button
                  disabled={playableIds.length === 0}
                  onClick={() => {
                    onTriggerRefreshEffect();
                    onAddSongs(playableIds, albumTitle);
                  }}
                  className={`flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-semibold transition disabled:opacity-40 ${
                    isEink
                      ? 'bg-white border-2 border-black shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                      : 'bg-stone-800 hover:bg-stone-700 text-stone-200 rounded-lg'
                  }`}
                >
                  <Plus className="w-3.5 h-3.5" />
                  Añadir a la cola
                </button>
              </div>

              {/* Track list */}
              <div className="pt-2">
                <div
                  className={`text-xs font-bold uppercase tracking-wider py-1 px-2 mb-2 ${
                    isEink ? 'bg-black text-white' : 'bg-stone-800 text-stone-300 rounded'
                  }`}
                >
                  — CANCIONES —
                </div>

                {songs.length === 0 ? (
                  <div className="py-6 text-center text-xs text-stone-500">
                    Este álbum no tiene canciones disponibles.
                  </div>
                ) : (
                  <div className="space-y-1">
                    {songs.map((song, index) => (
                      <div
                        key={song.id}
                        className={`flex items-center justify-between px-3 py-2 text-sm transition ${
                          isEink
                            ? 'border-b border-stone-200 hover:bg-stone-100'
                            : 'hover:bg-stone-800/60 rounded-lg border-b border-stone-800/40'
                        }`}
                      >
                        <div className="flex items-center gap-3 truncate pr-2">
                          <span className="text-xs font-mono text-stone-400 w-5 shrink-0 text-right">
                            {song.track ?? index + 1}
                          </span>
                          <span className="font-medium truncate">{song.title}</span>
                          {song.duration && (
                            <span className="text-xs text-stone-400 shrink-0 font-mono">
                              ({formatDuration(song.duration)})
                            </span>
                          )}
                        </div>
                        <div className="flex items-center gap-1.5 shrink-0">
                          <button
                            onClick={() => {
                              onTriggerRefreshEffect();
                              onPlaySongs([song.id], song.title);
                            }}
                            className={`p-1.5 rounded transition ${
                              isEink
                                ? 'bg-black text-white hover:bg-stone-800'
                                : 'bg-white text-black hover:bg-stone-200'
                            }`}
                            title="Reproducir"
                          >
                            <Play className="w-3.5 h-3.5 fill-current ml-0.5" />
                          </button>
                          <button
                            onClick={() => {
                              onTriggerRefreshEffect();
                              onAddSongs([song.id], song.title);
                            }}
                            className={`p-1.5 rounded transition ${
                              isEink
                                ? 'border border-black hover:bg-stone-100'
                                : 'border border-stone-700 hover:bg-stone-800 text-stone-300'
                            }`}
                            title="Añadir a la cola"
                          >
                            <Plus className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Fullscreen Cover Art Modal (matches ImageViewer in main.lua) */}
      {showFullCover && coverUrl && (
        <div
          className="fixed inset-0 z-50 bg-black/95 flex flex-col items-center justify-center p-4 cursor-pointer"
          onClick={() => setShowFullCover(false)}
        >
          <div className="absolute top-4 right-4 text-white p-2">
            <X className="w-6 h-6" />
          </div>
          <img
            src={coverUrl}
            alt={albumTitle}
            className={`max-w-full max-h-[80vh] object-contain ${
              isEink ? 'border-4 border-white grayscale contrast-125' : 'rounded-xl shadow-2xl'
            }`}
          />
          <p className="text-white mt-4 font-semibold text-center">{albumTitle}</p>
          <p className="text-stone-400 text-xs mt-1">Toca en cualquier parte para cerrar</p>
        </div>
      )}
    </div>
  );
};
