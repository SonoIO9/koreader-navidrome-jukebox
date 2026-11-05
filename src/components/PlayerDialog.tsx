import React from 'react';
import {
  SkipBack,
  Play,
  Square,
  SkipForward,
  Shuffle,
  RotateCw,
  X,
  Music,
  ListMusic,
} from 'lucide-react';
import { JukeboxPlaylist } from '../types';
import { subsonicService } from '../services/subsonic';

interface PlayerDialogProps {
  playlist: JukeboxPlaylist | null;
  isLoading: boolean;
  onClose: () => void;
  onRefresh: () => void;
  onOpenQueue: () => void;
  onTriggerRefreshEffect: () => void;
  isEink: boolean;
}

export const PlayerDialog: React.FC<PlayerDialogProps> = ({
  playlist,
  isLoading,
  onClose,
  onRefresh,
  onOpenQueue,
  onTriggerRefreshEffect,
  isEink,
}) => {
  const currentIndex = playlist?.currentIndex ?? -1;
  const entries = playlist?.entry || [];
  const currentSong = currentIndex >= 0 && currentIndex < entries.length ? entries[currentIndex] : null;
  const isPlaying = playlist?.playing ?? false;

  const handleToggle = async () => {
    onTriggerRefreshEffect();
    await subsonicService.togglePlayback(isPlaying);
    onRefresh();
  };

  const handleSkip = async (direction: number) => {
    onTriggerRefreshEffect();
    await subsonicService.skip(direction, currentIndex, entries.length);
    onRefresh();
  };

  const handleShuffle = async () => {
    onTriggerRefreshEffect();
    await subsonicService.shuffle();
    onRefresh();
  };

  const coverUrl = currentSong ? subsonicService.getCoverArtUrl(currentSong.coverArt, 400) : '';

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-3 bg-black/60 backdrop-blur-xs">
      {/* Modal Dialog Card */}
      <div
        className={`w-full max-w-md overflow-hidden transition-all ${
          isEink
            ? 'bg-[#ffffff] text-black border-4 border-black shadow-[6px_6px_0px_#000000]'
            : 'bg-stone-900 text-stone-100 rounded-2xl border border-stone-800 shadow-2xl'
        }`}
      >
        {/* Header bar */}
        <div
          className={`flex items-center justify-between px-4 py-2 border-b text-xs font-semibold uppercase tracking-wider ${
            isEink ? 'border-black bg-stone-100 text-black' : 'border-stone-800 bg-stone-950/60 text-stone-400'
          }`}
        >
          <span className="flex items-center gap-1.5">
            <Music className="w-3.5 h-3.5" />
            Reproductor (Now Playing)
          </span>
          <button
            onClick={() => {
              onTriggerRefreshEffect();
              onClose();
            }}
            className="p-1 hover:bg-stone-300 dark:hover:bg-stone-800 rounded transition"
            title="Cerrar"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Content body */}
        <div className="p-6 flex flex-col items-center text-center">
          {/* Cover Art Holder */}
          <div
            className={`w-56 h-56 relative flex items-center justify-center mb-5 overflow-hidden ${
              isEink
                ? 'border-3 border-black bg-stone-50 shadow-[3px_3px_0px_#000]'
                : 'rounded-xl border border-stone-800 bg-stone-950 shadow-inner'
            }`}
          >
            {coverUrl ? (
              <img
                src={coverUrl}
                alt={currentSong?.title || 'Cover'}
                className={`w-full h-full object-cover ${isEink ? 'grayscale contrast-125' : ''}`}
                onError={(e) => {
                  (e.currentTarget as HTMLElement).style.display = 'none';
                }}
              />
            ) : (
              <div className="flex flex-col items-center text-stone-400">
                <Music className="w-16 h-16 stroke-1 mb-2" />
                <span className="text-xs uppercase tracking-wider">Sin carátula</span>
              </div>
            )}

            {isLoading && (
              <div className="absolute inset-0 bg-white/70 dark:bg-black/70 flex items-center justify-center text-xs font-medium">
                Consultando el servidor...
              </div>
            )}
          </div>

          {/* Song info text */}
          <div className="w-full max-w-sm mb-4">
            <h2
              className={`text-xl font-bold leading-tight truncate px-2 ${
                isEink ? 'text-black' : 'text-stone-100'
              }`}
              title={currentSong ? currentSong.title : 'Nada en reproducción'}
            >
              {currentSong ? currentSong.title : 'Nada en reproducción'}
            </h2>
            <p
              className={`text-sm mt-1 truncate px-2 ${
                isEink ? 'text-stone-700 font-medium' : 'text-stone-400'
              }`}
            >
              {currentSong
                ? currentSong.isRadio
                  ? 'Emisora de Radio en directo'
                  : `${currentSong.artist} — ${currentSong.album}`
                : 'Añade canciones, álbumes o radios desde el menú'}
            </p>

            {/* Queue Counter badge */}
            <div className="mt-3 flex items-center justify-center gap-2">
              <span
                className={`text-xs px-2.5 py-0.5 rounded-full font-mono ${
                  isEink
                    ? 'border border-black bg-stone-100 text-black'
                    : 'bg-stone-800/80 text-stone-300 border border-stone-700'
                }`}
              >
                {entries.length > 0
                  ? `Pista ${currentIndex + 1} de ${entries.length}`
                  : 'Cola vacía'}
              </span>
              <button
                onClick={onOpenQueue}
                className={`text-xs flex items-center gap-1 px-2 py-0.5 rounded font-medium underline transition ${
                  isEink ? 'text-black hover:bg-stone-200' : 'text-stone-300 hover:text-white hover:bg-stone-800'
                }`}
                title="Ver lista de canciones"
              >
                <ListMusic className="w-3.5 h-3.5" />
                Ver cola
              </button>
            </div>
          </div>

          {/* 6 KOReader Fixed-Size Control Buttons Row */}
          <div className="flex items-center justify-center gap-2 mt-2">
            {/* 1. Prev */}
            <button
              onClick={() => handleSkip(-1)}
              disabled={entries.length === 0}
              className={`w-12 h-12 flex items-center justify-center transition disabled:opacity-30 ${
                isEink
                  ? 'bg-white border-2 border-black shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                  : 'bg-stone-800 hover:bg-stone-700 text-stone-100 rounded-xl active:scale-95'
              }`}
              title="Anterior"
            >
              <SkipBack className="w-5 h-5 fill-current" />
            </button>

            {/* 2. Play / Stop */}
            <button
              onClick={handleToggle}
              className={`w-13 h-13 flex items-center justify-center font-bold transition ${
                isEink
                  ? 'bg-black text-white border-2 border-black shadow-[2px_2px_0px_#555] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                  : 'bg-white text-black hover:bg-stone-200 rounded-xl shadow-lg active:scale-95'
              }`}
              title={isPlaying ? 'Detener' : 'Reproducir'}
            >
              {isPlaying ? (
                <Square className="w-6 h-6 fill-current" />
              ) : (
                <Play className="w-6 h-6 fill-current ml-0.5" />
              )}
            </button>

            {/* 3. Next */}
            <button
              onClick={() => handleSkip(1)}
              disabled={entries.length === 0}
              className={`w-12 h-12 flex items-center justify-center transition disabled:opacity-30 ${
                isEink
                  ? 'bg-white border-2 border-black shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                  : 'bg-stone-800 hover:bg-stone-700 text-stone-100 rounded-xl active:scale-95'
              }`}
              title="Siguiente"
            >
              <SkipForward className="w-5 h-5 fill-current" />
            </button>

            {/* 4. Shuffle */}
            <button
              onClick={handleShuffle}
              disabled={entries.length <= 1}
              className={`w-12 h-12 flex items-center justify-center transition disabled:opacity-30 ${
                isEink
                  ? 'bg-white border-2 border-black shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                  : 'bg-stone-800 hover:bg-stone-700 text-stone-100 rounded-xl active:scale-95'
              }`}
              title="Aleatorio (Shuffle)"
            >
              <Shuffle className="w-5 h-5" />
            </button>

            {/* 5. Refresh */}
            <button
              onClick={() => {
                onTriggerRefreshEffect();
                onRefresh();
              }}
              className={`w-12 h-12 flex items-center justify-center transition ${
                isEink
                  ? 'bg-white border-2 border-black shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                  : 'bg-stone-800 hover:bg-stone-700 text-stone-100 rounded-xl active:scale-95'
              }`}
              title="Recargar estado"
            >
              <RotateCw className={`w-5 h-5 ${isLoading ? 'animate-spin' : ''}`} />
            </button>

            {/* 6. Close */}
            <button
              onClick={() => {
                onTriggerRefreshEffect();
                onClose();
              }}
              className={`w-12 h-12 flex items-center justify-center transition ${
                isEink
                  ? 'bg-white border-2 border-black shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                  : 'bg-stone-800 hover:bg-stone-700 text-stone-100 rounded-xl active:scale-95'
              }`}
              title="Cerrar reproductor"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
