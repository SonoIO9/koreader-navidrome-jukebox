export interface Song {
  id: string;
  title: string;
  artist: string;
  artistId?: string;
  album: string;
  albumId?: string;
  track?: number;
  year?: number;
  genre?: string;
  duration?: number; // seconds
  coverArt?: string;
  playCount?: number;
  isRadio?: boolean;
  streamUrl?: string;
}

export interface RadioStation {
  id: string;
  name: string;
  streamUrl: string;
  homePageUrl?: string;
}

export interface Album {
  id: string;
  name: string;
  title?: string;
  artist: string;
  artistId?: string;
  year?: number;
  coverArt?: string;
  songCount?: number;
  duration?: number;
  playCount?: number;
  song?: Song[];
}

export interface Artist {
  id: string;
  name: string;
  albumCount?: number;
  coverArt?: string;
  album?: Album[];
}

export interface JukeboxPlaylist {
  currentIndex: number;
  playing: boolean;
  gain?: number;
  entry: Song[];
}

export interface ServerConfig {
  url: string;
  user: string;
  pass: string;
}

export interface ToastMessage {
  id: string;
  text: string;
  type?: 'info' | 'error' | 'success';
}
