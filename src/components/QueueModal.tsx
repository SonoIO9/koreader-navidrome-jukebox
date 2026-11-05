import React from 'react';
import { ListMusic, Play, Trash2, Shuffle, X } from 'lucide-react';
import { JukeboxPlaylist } from '../types';
import { subsonicService } from '../services/subsonic';

interface QueueModalProps {
  playlist: JukeboxPlaylist | null;
  onClose: () => void;
  onRefresh: () => void;
  onTriggerRefreshEffect: () => void;
  isEink: boolean;
}

export const QueueModal: React.FC<QueueModalProps> = ({
  playlist,
  onClose,
  onRefresh,
  onTriggerRefreshEffect,
  isEink,
}) => {
  const entries = playlist?.entry || [];
  const currentIndex = playlist?.currentIndex ?? -1;

  const handleSkipTo = async (index: number) => {
    onTriggerRefreshEffect();
    await subsonicService.apiRequest('jukeboxControl.view', {
      action: 'skip',
      index,
      offset: 0,
    });
    onRefresh();
  };

  const handleShuffle = async () => {
    onTriggerRefreshEffect();
    await subsonicService.shuffle();
    onRefresh();
  };

  const handleClear = async () => {
    onTriggerRefreshEffect();
    await subsonicService.clearQueue();
    onRefresh();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 bg-black/60 backdrop-blur-xs">
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
          <span className="flex items-center gap-2">
            <ListMusic className="w-4 h-4" />
            Cola del Jukebox ({entries.length} canciones)
          </span>
          <button onClick={onClose} className="p-1 hover:opacity-70">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Toolbar */}
        <div className="p-3 border-b border-stone-200 dark:border-stone-800 flex gap-2">
          <button
            onClick={handleShuffle}
            disabled={entries.length <= 1}
            className={`flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-semibold transition disabled:opacity-40 ${
              isEink
                ? 'bg-white border-2 border-black shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                : 'bg-stone-800 hover:bg-stone-700 text-stone-200 rounded-lg'
            }`}
          >
            <Shuffle className="w-3.5 h-3.5" />
            Aleatorio
          </button>

          <button
            onClick={handleClear}
            disabled={entries.length === 0}
            className={`flex-1 flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-semibold transition disabled:opacity-40 ${
              isEink
                ? 'bg-white border-2 border-black shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                : 'bg-stone-800 hover:bg-stone-700 text-red-400 rounded-lg'
            }`}
          >
            <Trash2 className="w-3.5 h-3.5" />
            Vaciar cola
          </button>
        </div>

        {/* List */}
        <div className="flex-1 overflow-y-auto p-3">
          {entries.length === 0 ? (
            <div className="py-12 text-center text-sm text-stone-500">
              La cola de reproducción está vacía. Añade música desde Buscar o Álbumes.
            </div>
          ) : (
            <div className="space-y-1.5">
              {entries.map((song, idx) => {
                const isCurrent = idx === currentIndex;
                return (
                  <div
                    key={`${song.id}-${idx}`}
                    className={`flex items-center justify-between p-2.5 text-sm transition ${
                      isCurrent
                        ? isEink
                          ? 'bg-black text-white font-bold'
                          : 'bg-stone-800 text-white border-l-4 border-amber-500 rounded-lg'
                        : isEink
                        ? 'border border-stone-200 hover:bg-stone-100'
                        : 'border border-stone-800/60 hover:bg-stone-800/40 rounded-lg text-stone-300'
                    }`}
                  >
                    <div className="flex items-center gap-3 truncate pr-2">
                      <span className="font-mono text-xs w-5 text-right opacity-70">
                        {idx + 1}
                      </span>
                      <div className="truncate">
                        <div className="truncate font-medium">{song.title}</div>
                        <div className="text-xs opacity-75 truncate">
                          {song.artist} • {song.album}
                        </div>
                      </div>
                    </div>

                    <div className="shrink-0 flex items-center gap-1.5">
                      {isCurrent ? (
                        <span className="text-xs uppercase tracking-wider px-2 py-0.5 rounded border border-current">
                          Sonando
                        </span>
                      ) : (
                        <button
                          onClick={() => handleSkipTo(idx)}
                          className={`p-1.5 rounded transition ${
                            isEink
                              ? 'border border-black hover:bg-stone-200 text-black'
                              : 'hover:bg-stone-700 text-stone-300'
                          }`}
                          title="Saltar a esta pista"
                        >
                          <Play className="w-3.5 h-3.5 fill-current ml-0.5" />
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
