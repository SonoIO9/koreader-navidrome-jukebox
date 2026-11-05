import React, { useEffect, useState } from 'react';
import { Flame, Sparkles, User, X } from 'lucide-react';
import { subsonicService } from '../services/subsonic';
import { Album } from '../types';

interface ArtistListItem {
  id?: string;
  name: string;
  score?: number;
}

interface ArtistListModalProps {
  title: string;
  mode: 'top' | 'discover';
  onClose: () => void;
  onSelectArtist: (id: string, name: string) => void;
  onTriggerRefreshEffect: () => void;
  isEink: boolean;
}

export const ArtistListModal: React.FC<ArtistListModalProps> = ({
  title,
  mode,
  onClose,
  onSelectArtist,
  onTriggerRefreshEffect,
  isEink,
}) => {
  const [artists, setArtists] = useState<ArtistListItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;
    async function loadArtists() {
      setIsLoading(true);

      if (mode === 'top') {
        // Aggregates playCount from frequent albums matching lines 749-792 of main.lua
        const { data } = await subsonicService.apiRequest('getAlbumList2.view', {
          type: 'frequent',
          size: 50,
        });

        if (isMounted) {
          if (data?.albumList2?.album) {
            const rawAlbums = Array.isArray(data.albumList2.album)
              ? data.albumList2.album
              : [data.albumList2.album];

            const artistData: Record<string, { id?: string; name: string; score: number }> = {};
            const order: string[] = [];

            for (const album of rawAlbums as Album[]) {
              const artistName = album.artist || 'Desconocido';
              const artistId = album.artistId ? String(album.artistId) : undefined;
              const key = artistId || `name:${artistName}`;

              if (!artistData[key]) {
                artistData[key] = { id: artistId, name: artistName, score: 0 };
                order.push(key);
              }
              const playCount = Number(album.playCount) || 1;
              artistData[key].score += playCount;
            }

            order.sort((a, b) => artistData[b].score - artistData[a].score);
            setArtists(order.map((key) => artistData[key]));
          }
          setIsLoading(false);
        }
      } else {
        // Discover artists - random selection from library matching lines 797-828 of main.lua
        const { data } = await subsonicService.apiRequest('getArtists.view', {});

        if (isMounted) {
          const index = Array.isArray(data?.artists?.index) ? data.artists.index : [];
          const allArtists: { id?: string; name: string }[] = [];

          for (const group of index) {
            const groupArtists = Array.isArray(group.artist) ? group.artist : group.artist ? [group.artist] : [];
            for (const art of groupArtists) {
              if (art.id || art.name) {
                allArtists.push({ id: art.id, name: art.name });
              }
            }
          }

          // Shuffle
          for (let i = allArtists.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [allArtists[i], allArtists[j]] = [allArtists[j], allArtists[i]];
          }

          setArtists(allArtists.slice(0, 15));
          setIsLoading(false);
        }
      }
    }

    loadArtists();
    return () => {
      isMounted = false;
    };
  }, [mode]);

  const Icon = mode === 'top' ? Flame : Sparkles;

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
            <Icon className="w-4 h-4 shrink-0" />
            <span className="truncate">{title}</span>
          </span>
          <button onClick={onClose} className="p-1 hover:opacity-70">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {isLoading ? (
            <div className="py-12 text-center text-sm text-stone-500">
              Analizando artistas en Navidrome...
            </div>
          ) : artists.length === 0 ? (
            <div className="py-12 text-center text-sm text-stone-500">
              {mode === 'top'
                ? 'Aún no hay suficiente historial de reproducción en el servidor.'
                : 'No se encontraron artistas en la biblioteca.'}
            </div>
          ) : (
            <div className="space-y-2">
              {artists.map((artist, idx) => (
                <button
                  key={`${artist.id || artist.name}-${idx}`}
                  onClick={() => {
                    onTriggerRefreshEffect();
                    if (artist.id) {
                      onSelectArtist(artist.id, artist.name);
                    }
                  }}
                  className={`w-full flex items-center justify-between p-3 text-left transition ${
                    isEink
                      ? 'border-2 border-black hover:bg-stone-100 shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                      : 'bg-stone-800/80 hover:bg-stone-700/80 rounded-xl text-stone-200 border border-stone-700/50'
                  }`}
                >
                  <div className="flex items-center gap-3 truncate">
                    <div
                      className={`w-8 h-8 flex items-center justify-center font-bold text-xs shrink-0 ${
                        isEink ? 'border border-black bg-white' : 'bg-stone-950 rounded-lg text-stone-300'
                      }`}
                    >
                      {idx + 1}
                    </div>
                    <span className="font-semibold text-sm truncate">{artist.name}</span>
                  </div>

                  {artist.score !== undefined && (
                    <span className="text-xs text-stone-500 shrink-0 ml-2 font-mono">
                      ≈{artist.score} reps
                    </span>
                  )}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
