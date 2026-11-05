import { Album, Artist, JukeboxPlaylist, RadioStation, ServerConfig, Song } from '../types';
import { INITIAL_ALBUMS, INITIAL_ARTISTS, INITIAL_JUKEBOX, INITIAL_RADIOS, INITIAL_SONGS } from '../mockData';

const STORAGE_KEY = 'koreader_navidrome_settings';

export const DEFAULT_CONFIG: ServerConfig = {
  url: '',
  user: '',
  pass: '',
};

class DemoSubsonicState {
  songs: Song[] = [...INITIAL_SONGS];
  albums: Album[] = [...INITIAL_ALBUMS];
  artists: Artist[] = [...INITIAL_ARTISTS];
  radios: RadioStation[] = [...INITIAL_RADIOS];
  jukebox: JukeboxPlaylist = {
    ...INITIAL_JUKEBOX,
    entry: [...INITIAL_JUKEBOX.entry],
  };

  getJukebox(): JukeboxPlaylist {
    return {
      ...this.jukebox,
      entry: [...this.jukebox.entry],
    };
  }

  jukeboxAction(action: string, params: Record<string, unknown> = {}) {
    switch (action) {
      case 'start':
        this.jukebox.playing = true;
        break;
      case 'stop':
        this.jukebox.playing = false;
        break;
      case 'skip': {
        const index = typeof params.index === 'number' ? params.index : this.jukebox.currentIndex + 1;
        if (this.jukebox.entry.length > 0) {
          this.jukebox.currentIndex = Math.max(0, Math.min(index, this.jukebox.entry.length - 1));
          this.jukebox.playing = true;
        }
        break;
      }
      case 'shuffle': {
        const currentSong = this.jukebox.entry[this.jukebox.currentIndex];
        const remaining = this.jukebox.entry.filter((_, idx) => idx !== this.jukebox.currentIndex);
        for (let i = remaining.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [remaining[i], remaining[j]] = [remaining[j], remaining[i]];
        }
        this.jukebox.entry = currentSong ? [currentSong, ...remaining] : remaining;
        this.jukebox.currentIndex = 0;
        break;
      }
      case 'clear':
        this.jukebox.entry = [];
        this.jukebox.currentIndex = -1;
        this.jukebox.playing = false;
        break;
      case 'set': {
        const rawIds = Array.isArray(params.id) ? params.id : [params.id];
        const ids = rawIds.map(String);

        // Check if ID is a radio station
        const radioMatch = this.radios.find(r => ids.includes(r.id));
        if (radioMatch) {
          const radioSong: Song = {
            id: radioMatch.id,
            title: radioMatch.name,
            artist: 'Emisora de Radio',
            album: 'Radio en directo',
            isRadio: true,
            streamUrl: radioMatch.streamUrl,
          };
          this.jukebox.entry = [radioSong];
          this.jukebox.currentIndex = 0;
          this.jukebox.playing = true;
        } else {
          const selected = this.songs.filter(s => ids.includes(s.id));
          if (selected.length > 0) {
            this.jukebox.entry = selected;
            this.jukebox.currentIndex = 0;
            this.jukebox.playing = true;
          }
        }
        break;
      }
      case 'add': {
        const rawIds = Array.isArray(params.id) ? params.id : [params.id];
        const ids = rawIds.map(String);

        const radioMatch = this.radios.find(r => ids.includes(r.id));
        if (radioMatch) {
          const radioSong: Song = {
            id: radioMatch.id,
            title: radioMatch.name,
            artist: 'Emisora de Radio',
            album: 'Radio en directo',
            isRadio: true,
            streamUrl: radioMatch.streamUrl,
          };
          this.jukebox.entry.push(radioSong);
        } else {
          const selected = this.songs.filter(s => ids.includes(s.id));
          this.jukebox.entry.push(...selected);
        }

        if (this.jukebox.currentIndex === -1 && this.jukebox.entry.length > 0) {
          this.jukebox.currentIndex = 0;
        }
        break;
      }
    }
    return this.getJukebox();
  }

  search(query: string) {
    const q = query.toLowerCase().trim();
    const artists = this.artists.filter(a => a.name.toLowerCase().includes(q));
    const albums = this.albums.filter(a => a.name.toLowerCase().includes(q) || a.artist.toLowerCase().includes(q));
    const songs = this.songs.filter(s => s.title.toLowerCase().includes(q) || s.artist.toLowerCase().includes(q));
    return { artist: artists, album: albums, song: songs };
  }
}

const demoState = new DemoSubsonicState();

export class SubsonicService {
  private config: ServerConfig;

  constructor() {
    this.config = this.loadConfig();
  }

  public loadConfig(): ServerConfig {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        return { ...DEFAULT_CONFIG, ...JSON.parse(stored) };
      }
    } catch {
      // Fallback
    }
    return { ...DEFAULT_CONFIG };
  }

  public saveConfig(newConfig: Partial<ServerConfig>): ServerConfig {
    let cleanUrl = (newConfig.url || this.config.url || '').trim().replace(/\/+$/, '');
    if (cleanUrl !== '' && !cleanUrl.match(/^https?:\/\//i)) {
      cleanUrl = 'http://' + cleanUrl;
    }

    this.config = {
      url: cleanUrl,
      user: (newConfig.user !== undefined ? newConfig.user : this.config.user).trim(),
      pass: newConfig.pass !== undefined ? newConfig.pass : this.config.pass,
    };

    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.config));
    } catch {
      // ignore
    }
    return this.config;
  }

  public getConfig(): ServerConfig {
    return { ...this.config };
  }

  public isConfigured(): boolean {
    return Boolean(this.config.url && this.config.user && this.config.pass);
  }

  public async apiRequest(endpoint: string, params: Record<string, unknown> = {}): Promise<{ data: any; error?: string }> {
    if (!this.isConfigured()) {
      return this.handleDemoRequest(endpoint, params);
    }

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 12000);

      const res = await fetch('/api/subsonic/proxy', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          serverUrl: this.config.url,
          user: this.config.user,
          pass: this.config.pass,
          endpoint,
          params,
        }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      const json = await res.json();
      const subResp = json['subsonic-response'];

      if (!subResp) {
        return { data: null, error: 'Respuesta inesperada del servidor Navidrome' };
      }

      if (subResp.status === 'failed') {
        return { data: null, error: subResp.error?.message || 'La solicitud a Navidrome falló' };
      }

      return { data: subResp };
    } catch (err: unknown) {
      const error = err as Error;
      const isTimeout = error.name === 'AbortError';
      return {
        data: null,
        error: isTimeout
          ? 'Tiempo de espera agotado al conectar con Navidrome'
          : `Error de conexión: ${error.message || 'No se pudo conectar'}`,
      };
    }
  }

  private handleDemoRequest(endpoint: string, params: Record<string, unknown>): { data: any; error?: string } {
    if (endpoint === 'ping.view') {
      return { data: { status: 'ok', version: '1.16.1' } };
    }

    if (endpoint === 'jukeboxControl.view') {
      const action = String(params.action || 'get');
      if (action === 'get') {
        return { data: { jukeboxPlaylist: demoState.getJukebox() } };
      }
      const updated = demoState.jukeboxAction(action, params);
      return { data: { jukeboxPlaylist: updated } };
    }

    if (endpoint === 'getInternetRadioStations.view') {
      return {
        data: {
          internetRadioStations: {
            station: demoState.radios,
          },
        },
      };
    }

    if (endpoint === 'search3.view') {
      const query = String(params.query || '');
      const results = demoState.search(query);
      return { data: { searchResult3: results } };
    }

    if (endpoint === 'getArtist.view') {
      const id = String(params.id);
      const artist = demoState.artists.find(a => a.id === id);
      const artistAlbums = demoState.albums.filter(a => a.artistId === id || a.artist === artist?.name);
      return { data: { artist: { ...artist, album: artistAlbums } } };
    }

    if (endpoint === 'getAlbum.view') {
      const id = String(params.id);
      const album = demoState.albums.find(a => a.id === id) || {
        id,
        name: 'Selected Album',
        artist: 'Unknown Artist',
        song: demoState.songs.filter(s => s.albumId === id),
      };
      return { data: { album } };
    }

    if (endpoint === 'getAlbumList2.view') {
      const type = String(params.type || 'newest');
      let albums = [...demoState.albums];
      if (type === 'random') {
        albums.sort(() => Math.random() - 0.5);
      } else if (type === 'frequent') {
        albums.sort((a, b) => (b.playCount || 0) - (a.playCount || 0));
      }
      return { data: { albumList2: { album: albums } } };
    }

    if (endpoint === 'getArtists.view') {
      return {
        data: {
          artists: {
            index: [{ name: 'A-Z', artist: demoState.artists }],
          },
        },
      };
    }

    return { data: {} };
  }

  public getCoverArtUrl(coverId?: string, size = 400): string {
    if (!coverId) return '';
    if (coverId.startsWith('http://') || coverId.startsWith('https://')) {
      return coverId;
    }
    if (!this.isConfigured()) {
      const match = demoState.songs.find(s => s.coverArt === coverId || s.id === coverId || s.albumId === coverId);
      if (match?.coverArt) return match.coverArt;
      return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=600&q=80';
    }
    const cleanUrl = encodeURIComponent(this.config.url);
    const u = encodeURIComponent(this.config.user);
    const p = encodeURIComponent(this.config.pass);
    return `/api/subsonic/cover?serverUrl=${cleanUrl}&user=${u}&pass=${p}&id=${encodeURIComponent(coverId)}&size=${size}`;
  }

  public async getNowPlaying(): Promise<{ playlist?: JukeboxPlaylist; error?: string }> {
    const { data, error } = await this.apiRequest('jukeboxControl.view', { action: 'get' });
    if (error) return { error };
    return { playlist: data?.jukeboxPlaylist };
  }

  public async togglePlayback(isCurrentlyPlaying: boolean): Promise<{ success: boolean; error?: string }> {
    const action = isCurrentlyPlaying ? 'stop' : 'start';
    const { error } = await this.apiRequest('jukeboxControl.view', { action });
    return { success: !error, error };
  }

  public async skip(direction: number, currentIndex: number, total: number): Promise<{ success: boolean; error?: string }> {
    if (total === 0) return { success: false, error: 'Cola vacía' };
    let newIndex = currentIndex + direction;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= total) newIndex = total - 1;

    const { error } = await this.apiRequest('jukeboxControl.view', {
      action: 'skip',
      index: newIndex,
      offset: 0,
    });
    return { success: !error, error };
  }

  public async shuffle(): Promise<{ success: boolean; error?: string }> {
    const { error } = await this.apiRequest('jukeboxControl.view', { action: 'shuffle' });
    return { success: !error, error };
  }

  public async clearQueue(): Promise<{ success: boolean; error?: string }> {
    const { error } = await this.apiRequest('jukeboxControl.view', { action: 'clear' });
    return { success: !error, error };
  }

  public async playSongs(ids: string[]): Promise<{ success: boolean; error?: string }> {
    if (!ids || ids.length === 0) return { success: false, error: 'No hay canciones seleccionadas' };
    const { error: setError } = await this.apiRequest('jukeboxControl.view', { action: 'set', id: ids });
    if (setError) return { success: false, error: setError };
    const { error: startError } = await this.apiRequest('jukeboxControl.view', { action: 'start' });
    return { success: !startError, error: startError };
  }

  public async addSongs(ids: string[]): Promise<{ success: boolean; error?: string }> {
    if (!ids || ids.length === 0) return { success: false, error: 'No hay canciones seleccionadas' };
    const { error } = await this.apiRequest('jukeboxControl.view', { action: 'add', id: ids });
    return { success: !error, error };
  }

  public async getRadioStations(): Promise<{ stations: RadioStation[]; error?: string }> {
    const { data, error } = await this.apiRequest('getInternetRadioStations.view', {});
    if (error) return { stations: [], error };
    const rawStations = data?.internetRadioStations?.station;
    const stations: RadioStation[] = Array.isArray(rawStations)
      ? rawStations
      : rawStations
      ? [rawStations]
      : [];
    return { stations };
  }

  public async playRadio(radio: RadioStation): Promise<{ success: boolean; error?: string }> {
    const { error: setError } = await this.apiRequest('jukeboxControl.view', { action: 'set', id: radio.id });
    if (setError) return { success: false, error: setError };
    const { error: startError } = await this.apiRequest('jukeboxControl.view', { action: 'start' });
    return { success: !startError, error: startError };
  }

  public async addRadio(radio: RadioStation): Promise<{ success: boolean; error?: string }> {
    const { error } = await this.apiRequest('jukeboxControl.view', { action: 'add', id: radio.id });
    return { success: !error, error };
  }

  public async testConnection(url: string, user: string, pass: string): Promise<{ ok: boolean; message: string }> {
    let cleanUrl = url.trim().replace(/\/+$/, '');
    if (cleanUrl !== '' && !cleanUrl.match(/^https?:\/\//i)) {
      cleanUrl = 'http://' + cleanUrl;
    }

    if (!cleanUrl || !user || !pass) {
      return { ok: false, message: 'Introduce la URL del servidor, usuario y contraseña' };
    }

    try {
      const res = await fetch('/api/subsonic/proxy', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          serverUrl: cleanUrl,
          user: user.trim(),
          pass,
          endpoint: 'ping.view',
        }),
      });
      const json = await res.json();
      const subResp = json['subsonic-response'];
      if (subResp && subResp.status === 'ok') {
        return {
          ok: true,
          message: `¡Conexión exitosa con Navidrome! (Subsonic API v${subResp.version || '1.12+'})`,
        };
      }
      return { ok: false, message: subResp?.error?.message || 'Conexión rechazada por el servidor Navidrome' };
    } catch (err: unknown) {
      const error = err as Error;
      return { ok: false, message: error.message || 'No se pudo alcanzar el servidor' };
    }
  }
}

export const subsonicService = new SubsonicService();
