import React, { useState } from 'react';
import { Settings, CheckCircle2, AlertCircle, Loader2, X, Eye, EyeOff } from 'lucide-react';
import { ServerConfig } from '../types';
import { subsonicService } from '../services/subsonic';

interface ConfigModalProps {
  currentConfig: ServerConfig;
  onClose: () => void;
  onSave: (newConfig: ServerConfig) => void;
}

export const ConfigModal: React.FC<ConfigModalProps> = ({
  currentConfig,
  onClose,
  onSave,
}) => {
  const [url, setUrl] = useState(currentConfig.url);
  const [user, setUser] = useState(currentConfig.user);
  const [pass, setPass] = useState(currentConfig.pass);
  const [showPassword, setShowPassword] = useState(false);

  const [testStatus, setTestStatus] = useState<{
    loading: boolean;
    success?: boolean;
    message?: string;
  }>({ loading: false });

  const handleTestConnection = async () => {
    let cleanUrl = url.trim().replace(/\/+$/, '');
    if (cleanUrl !== '' && !cleanUrl.match(/^https?:\/\//i)) {
      cleanUrl = 'http://' + cleanUrl;
      setUrl(cleanUrl);
    }

    if (!cleanUrl) {
      setTestStatus({
        loading: false,
        success: false,
        message: 'Por favor introduce la URL del servidor Navidrome',
      });
      return;
    }
    if (!user.trim()) {
      setTestStatus({
        loading: false,
        success: false,
        message: 'Por favor introduce el nombre de usuario de Navidrome',
      });
      return;
    }
    if (!pass) {
      setTestStatus({
        loading: false,
        success: false,
        message: 'Por favor introduce la contraseña de Navidrome',
      });
      return;
    }

    setTestStatus({ loading: true });
    const res = await subsonicService.testConnection(cleanUrl, user.trim(), pass);
    setTestStatus({
      loading: false,
      success: res.ok,
      message: res.message,
    });
  };

  const handleSave = () => {
    let cleanUrl = url.trim().replace(/\/+$/, '');
    if (cleanUrl !== '' && !cleanUrl.match(/^https?:\/\//i)) {
      cleanUrl = 'http://' + cleanUrl;
    }

    const newConfig: ServerConfig = {
      url: cleanUrl,
      user: user.trim(),
      pass: pass,
    };
    onSave(newConfig);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 bg-black/60 backdrop-blur-xs">
      <div className="w-full max-w-md max-h-[90vh] flex flex-col overflow-hidden bg-white text-black border-4 border-black shadow-[6px_6px_0px_#000]">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-black bg-stone-100 font-bold">
          <span className="flex items-center gap-2">
            <Settings className="w-4 h-4" />
            Configurar servidor y cuenta
          </span>
          <button onClick={onClose} className="p-1 hover:opacity-70">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Form fields */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4 text-sm">
          {/* Server URL */}
          <div>
            <label className="block font-semibold mb-1">Servidor Navidrome</label>
            <input
              type="text"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="Ej: http://192.168.1.100:4533 o https://musica.ejemplo.com"
              className="w-full px-3 py-2 text-sm outline-hidden bg-white border-2 border-black text-black placeholder:text-stone-400"
            />
            <p className="text-xs text-stone-500 mt-1">
              Dirección de tu servidor (si omites http:// se añadirá automáticamente)
            </p>
          </div>

          {/* User */}
          <div>
            <label className="block font-semibold mb-1">Usuario Navidrome</label>
            <input
              type="text"
              value={user}
              onChange={(e) => setUser(e.target.value)}
              placeholder="Nombre de usuario"
              className="w-full px-3 py-2 text-sm outline-hidden bg-white border-2 border-black text-black placeholder:text-stone-400"
            />
          </div>

          {/* Password */}
          <div>
            <label className="block font-semibold mb-1">Contraseña Navidrome</label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                value={pass}
                onChange={(e) => setPass(e.target.value)}
                placeholder="Contraseña de tu cuenta"
                className="w-full px-3 py-2 pr-10 text-sm outline-hidden bg-white border-2 border-black text-black placeholder:text-stone-400"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-stone-600 hover:text-black p-1"
                title={showPassword ? 'Ocultar' : 'Mostrar'}
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
            <p className="text-xs text-stone-500 mt-1">
              Se guarda en los ajustes de KOReader en tu dispositivo
            </p>
          </div>

          {/* Test connection button */}
          <div className="pt-1">
            <button
              type="button"
              disabled={testStatus.loading}
              onClick={handleTestConnection}
              className="w-full py-2 px-3 text-xs font-bold flex items-center justify-center gap-2 bg-stone-100 hover:bg-stone-200 border-2 border-black shadow-[2px_2px_0px_#000] active:translate-x-0.5 active:translate-y-0.5"
            >
              {testStatus.loading ? (
                <>
                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                  Probando conexión con Navidrome...
                </>
              ) : (
                'Probar conexión ahora'
              )}
            </button>

            {testStatus.message && (
              <div
                className={`mt-2 p-2.5 text-xs border-2 flex items-center gap-2 font-medium ${
                  testStatus.success
                    ? 'border-black bg-stone-100 text-black'
                    : 'border-red-600 bg-red-50 text-red-700'
                }`}
              >
                {testStatus.success ? (
                  <CheckCircle2 className="w-4 h-4 shrink-0" />
                ) : (
                  <AlertCircle className="w-4 h-4 shrink-0" />
                )}
                <span>{testStatus.message}</span>
              </div>
            )}
          </div>
        </div>

        {/* Footer buttons */}
        <div className="flex items-center justify-end gap-2 p-3 border-t border-black bg-stone-100">
          <button
            onClick={onClose}
            className="px-4 py-1.5 text-xs font-semibold hover:underline text-black"
          >
            Cancelar
          </button>
          <button
            onClick={handleSave}
            className="px-4 py-1.5 text-xs font-bold bg-black text-white border-2 border-black shadow-[2px_2px_0px_#555] active:translate-x-0.5 active:translate-y-0.5"
          >
            Guardar
          </button>
        </div>
      </div>
    </div>
  );
};
