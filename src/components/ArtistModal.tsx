import React, { useEffect, useState } from 'react';
import { User, Disc, X } from 'lucide-react';
import { subsonicService } from '../services/subsonic';
import { Album } from '../types';

interface ArtistModalProps {
  artistId: string;
  artistName: string;
  onClose: () => void;
  onSelectAlbum: (id: string, title: string) => void;
  onTriggerRefreshEffect: () => void;
  isEink: boolean;
}

export const ArtistModal: React.FC<ArtistModalProps> = ({
  artistId,
  artistName,
  onClose,
  onSelectAlbum,
  onTriggerRefreshEffect,
  isEink,
}) => {
  const [albums, setAlbums] = useState<Album[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;
    async function loadArtist() {
      setIsLoading(true);
      const { data } = await subsonicService.apiRequest('getArtist.view', { id: artistId });
      if (isMounted) {
        if (data?.artist?.album) {
          const list = Array.isArray(data.artist.album) ? data.artist.album : [data.artist.album];
          setAlbums(list);
        }
        setIsLoading(false);
      }
    }
    loadArtist();
    return () => {
      isMounted = false;
    };
  }, [artistId]);

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-3 bg-black/60 backdrop-blur-xs">
      <div
        className={`w-full max-w-lg max-h-[85vh] flex flex-col overflow-hidden ${
          isEink
            ? 'bg-white text-black border-4 border-black shadow-[6px_6px_0px_#000]'
            : 'bg-stone-900 text-stone-100 rounded-2xl border border-stone-800 shadow-2xl'
        }`}
      >
        <div
          className={`flex items-center justify-between px-4 py-3 border-b ${
            isEink ? 'border-black bg-stone-100 font-bold' : 'border-stone-800 bg-stone-950 font-semibold'
          }`}
        >
          <span className="flex items-center gap-2 truncate">
            <User className="w-4 h-4 shrink-0" />
            <span className="truncate">Álbumes: {artistName}</span>
          </span>
          <button onClick={onClose} className="p-1 hover:opacity-70">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {isLoading ? (
            <div className="py-12 text-center text-sm text-stone-500">
              Cargando discografía desde Navidrome...
            </div>
          ) : albums.length === 0 ? (
            <div className="py-12 text-center text-sm text-stone-500">
              Este artista no tiene álbumes registrados.
            </div>
          ) : (
            <div className="space-y-2">
              {albums.map((album) => {
                const cover = subsonicService.getCoverArtUrl(album.coverArt || album.id, 200);
                return (
                  <button
                    key={album.id}
                    onClick={() => {
                      onTriggerRefreshEffect();
                      onSelectAlbum(album.id, album.name || album.title || 'Álbum');
                    }}
                    className={`w-full flex items-center gap-3 p-3 text-left transition ${
                      isEink
                        ? 'border-2 border-black hover:bg-stone-100 shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                        : 'bg-stone-800/80 hover:bg-stone-700/80 rounded-xl text-stone-200 border border-stone-700/50'
                    }`}
                  >
                    {cover ? (
                      <img
                        src={cover}
                        alt=""
                        className={`w-12 h-12 object-cover shrink-0 ${
                          isEink ? 'border border-black grayscale contrast-125' : 'rounded-lg'
                        }`}
                      />
                    ) : (
                      <div
                        className={`w-12 h-12 flex items-center justify-center shrink-0 ${
                          isEink ? 'border border-black bg-stone-100' : 'bg-stone-950 rounded-lg'
                        }`}
                      >
                        <Disc className="w-5 h-5 text-stone-400" />
                      </div>
                    )}
                    <div className="truncate flex-1 min-w-0">
                      <div className="font-semibold text-sm truncate">{album.name || album.title}</div>
                      {album.year && <div className="text-xs text-stone-500">Año: {album.year}</div>}
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
