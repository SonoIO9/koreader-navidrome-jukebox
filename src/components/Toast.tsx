import React, { useEffect } from 'react';
import { ToastMessage } from '../types';

interface ToastProps {
  toasts: ToastMessage[];
  onDismiss: (id: string) => void;
  isEink: boolean;
}

export const Toast: React.FC<ToastProps> = ({ toasts, onDismiss, isEink }) => {
  useEffect(() => {
    if (toasts.length === 0) return;
    const timer = setTimeout(() => {
      onDismiss(toasts[0].id);
    }, 3200);
    return () => clearTimeout(timer);
  }, [toasts, onDismiss]);

  if (toasts.length === 0) return null;

  return (
    <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 flex flex-col gap-2 pointer-events-none max-w-md w-full px-4">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className={`pointer-events-auto p-3 text-center text-sm font-medium transition-all ${
            isEink
              ? 'bg-white text-black border-2 border-black shadow-[3px_3px_0px_#000]'
              : 'bg-stone-900 text-stone-100 rounded-lg shadow-xl border border-stone-700'
          }`}
        >
          <div className="text-xs uppercase tracking-wider text-stone-500 mb-0.5">Navidrome</div>
          <div className="whitespace-pre-line">{toast.text}</div>
        </div>
      ))}
    </div>
  );
};
