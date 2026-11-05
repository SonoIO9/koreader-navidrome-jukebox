import React, { useState } from 'react';
import { Search, User, Disc, Play, Plus, X } from 'lucide-react';
import { subsonicService } from '../services/subsonic';
import { Album, Artist, Song } from '../types';

interface SearchDialogProps {
  onClose: () => void;
  onSelectArtist: (id: string, name: string) => void;
  onSelectAlbum: (id: string, title: string) => void;
  onPlaySong: (song: Song) => void;
  onAddSong: (song: Song) => void;
  onTriggerRefreshEffect: () => void;
  isEink: boolean;
}

export const SearchDialog: React.FC<SearchDialogProps> = ({
  onClose,
  onSelectArtist,
  onSelectAlbum,
  onPlaySong,
  onAddSong,
  onTriggerRefreshEffect,
  isEink,
}) => {
  const [query, setQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [results, setResults] = useState<{
    artist: Artist[];
    album: Album[];
    song: Song[];
  } | null>(null);

  const handleSearch = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!query.trim()) return;

    onTriggerRefreshEffect();
    setIsSearching(true);
    const { data } = await subsonicService.apiRequest('search3.view', {
      query: query.trim(),
      artistCount: 10,
      albumCount: 10,
      songCount: 20,
    });
    setIsSearching(false);

    if (data?.searchResult3) {
      const res = data.searchResult3;
      setResults({
        artist: Array.isArray(res.artist) ? res.artist : res.artist ? [res.artist] : [],
        album: Array.isArray(res.album) ? res.album : res.album ? [res.album] : [],
        song: Array.isArray(res.song) ? res.song : res.song ? [res.song] : [],
      });
    } else {
      setResults({ artist: [], album: [], song: [] });
    }
  };

  const hasResults =
    results &&
    (results.artist.length > 0 || results.album.length > 0 || results.song.length > 0);

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-3 bg-black/60 backdrop-blur-xs">
      <div
        className={`w-full max-w-lg max-h-[85vh] flex flex-col overflow-hidden ${
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
          <span className="flex items-center gap-2">
            <Search className="w-4 h-4" />
            Buscar en Navidrome
          </span>
          <button onClick={onClose} className="p-1 hover:opacity-70">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Search input bar */}
        <form onSubmit={handleSearch} className="p-4 border-b border-stone-200 dark:border-stone-800 flex gap-2">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Artista, álbum o canción..."
            autoFocus
            className={`flex-1 px-3 py-2 text-sm outline-hidden ${
              isEink
                ? 'bg-white border-2 border-black text-black placeholder:text-stone-500'
                : 'bg-stone-950 border border-stone-700 text-stone-100 rounded-lg placeholder:text-stone-500'
            }`}
          />
          <button
            type="submit"
            disabled={isSearching || !query.trim()}
            className={`px-4 py-2 font-medium text-sm flex items-center gap-1.5 transition disabled:opacity-40 ${
              isEink
                ? 'bg-black text-white border-2 border-black shadow-[2px_2px_0px_#555] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                : 'bg-white text-black rounded-lg hover:bg-stone-200 font-semibold'
            }`}
          >
            <Search className="w-4 h-4" />
            Buscar
          </button>
        </form>

        {/* Results scroll list */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {isSearching && (
            <div className="py-8 text-center text-sm text-stone-500">
              Buscando en la biblioteca de Navidrome...
            </div>
          )}

          {!isSearching && results && !hasResults && (
            <div className="py-8 text-center text-sm text-stone-500">
              No se encontraron resultados para "{query}".
            </div>
          )}

          {!isSearching && results && hasResults && (
            <div className="space-y-4">
              {/* Artists Section */}
              {results.artist.length > 0 && (
                <div>
                  <div
                    className={`text-xs font-bold uppercase tracking-wider py-1 px-2 mb-2 ${
                      isEink ? 'bg-black text-white' : 'bg-stone-800 text-stone-300 rounded'
                    }`}
                  >
                    — ARTISTAS —
                  </div>
                  <div className="space-y-1">
                    {results.artist.map((artist) => (
                      <button
                        key={artist.id}
                        onClick={() => {
                          onTriggerRefreshEffect();
                          onSelectArtist(artist.id, artist.name);
                        }}
                        className={`w-full flex items-center gap-3 px-3 py-2 text-left text-sm transition ${
                          isEink
                            ? 'hover:bg-stone-100 border border-transparent hover:border-black'
                            : 'hover:bg-stone-800/80 rounded-lg text-stone-200'
                        }`}
                      >
                        <User className="w-4 h-4 text-stone-400 shrink-0" />
                        <span className="font-medium truncate">{artist.name}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Albums Section */}
              {results.album.length > 0 && (
                <div>
                  <div
                    className={`text-xs font-bold uppercase tracking-wider py-1 px-2 mb-2 ${
                      isEink ? 'bg-black text-white' : 'bg-stone-800 text-stone-300 rounded'
                    }`}
                  >
                    — ÁLBUMES —
                  </div>
                  <div className="space-y-1">
                    {results.album.map((album) => (
                      <button
                        key={album.id}
                        onClick={() => {
                          onTriggerRefreshEffect();
                          onSelectAlbum(album.id, album.name || album.title || 'Álbum');
                        }}
                        className={`w-full flex items-center gap-3 px-3 py-2 text-left text-sm transition ${
                          isEink
                            ? 'hover:bg-stone-100 border border-transparent hover:border-black'
                            : 'hover:bg-stone-800/80 rounded-lg text-stone-200'
                        }`}
                      >
                        <Disc className="w-4 h-4 text-stone-400 shrink-0" />
                        <div className="truncate">
                          <span className="font-semibold">{album.name || album.title}</span>
                          <span className="text-stone-500 text-xs ml-2">— {album.artist}</span>
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Songs Section */}
              {results.song.length > 0 && (
                <div>
                  <div
                    className={`text-xs font-bold uppercase tracking-wider py-1 px-2 mb-2 ${
                      isEink ? 'bg-black text-white' : 'bg-stone-800 text-stone-300 rounded'
                    }`}
                  >
                    — CANCIONES —
                  </div>
                  <div className="space-y-1">
                    {results.song.map((song) => (
                      <div
                        key={song.id}
                        className={`flex items-center justify-between px-3 py-2 text-sm transition ${
                          isEink
                            ? 'border-b border-stone-200 hover:bg-stone-50'
                            : 'hover:bg-stone-800/60 rounded-lg border-b border-stone-800/50'
                        }`}
                      >
                        <div className="truncate pr-2">
                          <div className="font-medium text-sm truncate">{song.title}</div>
                          <div className="text-xs text-stone-500 truncate">
                            {song.artist} • {song.album}
                          </div>
                        </div>
                        <div className="flex items-center gap-1.5 shrink-0">
                          <button
                            onClick={() => {
                              onTriggerRefreshEffect();
                              onPlaySong(song);
                            }}
                            className={`p-1.5 rounded transition ${
                              isEink
                                ? 'bg-black text-white hover:bg-stone-800'
                                : 'bg-white text-black hover:bg-stone-200'
                            }`}
                            title="Reproducir ahora"
                          >
                            <Play className="w-3.5 h-3.5 fill-current ml-0.5" />
                          </button>
                          <button
                            onClick={() => {
                              onTriggerRefreshEffect();
                              onAddSong(song);
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
                </div>
              )}
            </div>
          )}

          {!results && !isSearching && (
            <div className="py-8 text-center text-sm text-stone-500">
              Introduce un término de búsqueda para explorar tu colección.
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
