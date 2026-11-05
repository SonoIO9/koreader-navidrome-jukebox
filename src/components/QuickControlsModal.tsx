import React from 'react';
import { Square, Play, SkipForward, Trash2, X } from 'lucide-react';
import { subsonicService } from '../services/subsonic';

interface QuickControlsModalProps {
  onClose: () => void;
  onRefresh: () => void;
  onNotify: (text: string) => void;
  onTriggerRefreshEffect: () => void;
  isEink: boolean;
}

export const QuickControlsModal: React.FC<QuickControlsModalProps> = ({
  onClose,
  onRefresh,
  onNotify,
  onTriggerRefreshEffect,
  isEink,
}) => {
  const handleAction = async (action: string) => {
    onTriggerRefreshEffect();
    const { error } = await subsonicService.apiRequest('jukeboxControl.view', { action });
    if (error) {
      onNotify('Error: ' + error);
      return;
    }

    const messages: Record<string, string> = {
      start: 'Reproducción iniciada.',
      stop: 'Reproducción detenida.',
      skip: 'Pasando a la siguiente canción.',
      clear: 'Cola vaciada.',
    };
    onNotify(messages[action] || 'Listo.');
    onRefresh();
    onClose();
  };

  const items = [
    {
      id: 'stop',
      label: 'Detener reproducción',
      icon: Square,
      action: 'stop',
    },
    {
      id: 'start',
      label: 'Reanudar reproducción',
      icon: Play,
      action: 'start',
    },
    {
      id: 'skip',
      label: 'Siguiente canción',
      icon: SkipForward,
      action: 'skip',
    },
    {
      id: 'clear',
      label: 'Vaciar cola',
      icon: Trash2,
      action: 'clear',
    },
  ];

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
      <div
        className={`w-full max-w-sm overflow-hidden ${
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
          <span>Controles rápidos del Jukebox</span>
          <button onClick={onClose} className="p-1 hover:opacity-70">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="p-3 space-y-2">
          {items.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                onClick={() => handleAction(item.action)}
                className={`w-full flex items-center gap-3 px-4 py-3 text-left font-medium text-sm transition ${
                  isEink
                    ? 'bg-white border-2 border-black hover:bg-stone-100 shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5 active:shadow-none'
                    : 'bg-stone-800/80 hover:bg-stone-700/80 text-stone-200 rounded-xl active:scale-[0.99]'
                }`}
              >
                <Icon className="w-4 h-4 fill-current shrink-0" />
                <span>{item.label}</span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
};
