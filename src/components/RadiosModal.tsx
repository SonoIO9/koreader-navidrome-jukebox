import React, { useEffect, useState } from 'react';
import { Radio, Play, Plus, ExternalLink, X } from 'lucide-react';
import { RadioStation } from '../types';
import { subsonicService } from '../services/subsonic';

interface RadiosModalProps {
  onClose: () => void;
  onPlayRadio: (station: RadioStation) => void;
  onAddRadio: (station: RadioStation) => void;
  onNotify: (text: string, type?: 'info' | 'error' | 'success') => void;
}

export const RadiosModal: React.FC<RadiosModalProps> = ({
  onClose,
  onPlayRadio,
  onAddRadio,
  onNotify,
}) => {
  const [stations, setStations] = useState<RadioStation[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;
    async function loadRadios() {
      setIsLoading(true);
      const { stations: list, error } = await subsonicService.getRadioStations();
      if (isMounted) {
        if (error) {
          onNotify(error, 'error');
        } else {
          setStations(list);
        }
        setIsLoading(false);
      }
    }
    loadRadios();
    return () => {
      isMounted = false;
    };
  }, [onNotify]);

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-3 bg-black/60 backdrop-blur-xs">
      <div className="w-full max-w-lg max-h-[85vh] flex flex-col overflow-hidden bg-white text-black border-4 border-black shadow-[6px_6px_0px_#000]">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-black bg-stone-100 font-bold">
          <span className="flex items-center gap-2">
            <Radio className="w-4 h-4" />
            Radios de Navidrome
          </span>
          <button onClick={onClose} className="p-1 hover:opacity-70" title="Cerrar">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Content list */}
        <div className="flex-1 overflow-y-auto p-4">
          {isLoading ? (
            <div className="py-12 text-center text-sm text-stone-500">
              Consultando emisoras de radio en Navidrome...
            </div>
          ) : stations.length === 0 ? (
            <div className="py-12 text-center text-sm text-stone-600 space-y-2">
              <p className="font-semibold">No tienes emisoras de radio configuradas en Navidrome.</p>
              <p className="text-xs text-stone-500">
                Añade tus radios favoritas (URL de streaming) desde la sección "Radios" en la interfaz web de Navidrome.
              </p>
            </div>
          ) : (
            <div className="space-y-2.5">
              {stations.map((station) => (
                <div
                  key={station.id}
                  className="p-3 border-2 border-black bg-white hover:bg-stone-50 shadow-[2px_2px_0px_#000] flex flex-col sm:flex-row sm:items-center justify-between gap-3"
                >
                  <div className="truncate flex-1 min-w-0">
                    <div className="font-bold text-sm truncate flex items-center gap-2">
                      <Radio className="w-4 h-4 shrink-0" />
                      <span className="truncate">{station.name}</span>
                    </div>
                    {station.streamUrl && (
                      <div className="text-xs text-stone-500 font-mono truncate mt-0.5">
                        {station.streamUrl}
                      </div>
                    )}
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <button
                      onClick={() => onPlayRadio(station)}
                      className="px-3 py-1.5 bg-black text-white text-xs font-semibold flex items-center gap-1.5 border border-black shadow-[1px_1px_0px_#555] active:translate-x-0.5 active:translate-y-0.5"
                      title="Reproducir ahora en el Jukebox"
                    >
                      <Play className="w-3.5 h-3.5 fill-current ml-0.5" />
                      Reproducir
                    </button>

                    <button
                      onClick={() => onAddRadio(station)}
                      className="px-2.5 py-1.5 bg-white text-black text-xs font-semibold flex items-center gap-1 border-2 border-black hover:bg-stone-100 shadow-[1px_1px_0px_#000] active:translate-x-0.5 active:translate-y-0.5"
                      title="Añadir a la cola del Jukebox"
                    >
                      <Plus className="w-3.5 h-3.5" />
                      Cola
                    </button>

                    {station.homePageUrl && (
                      <a
                        href={station.homePageUrl}
                        target="_blank"
                        rel="noreferrer"
                        className="p-1.5 border border-stone-300 hover:border-black text-stone-600 rounded"
                        title="Abrir web de la radio"
                      >
                        <ExternalLink className="w-3.5 h-3.5" />
                      </a>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
