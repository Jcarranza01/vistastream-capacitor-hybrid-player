import type { PluginListenerHandle } from '@capacitor/core';

export type PlaybackEngine = 'auto' | 'avplayer' | 'vlc';
export type ActivePlaybackEngine = Exclude<PlaybackEngine, 'auto'>;

export interface OpenOptions {
  url: string;
  title?: string;
  posterUrl?: string;
  startAt?: number;
  engine?: PlaybackEngine;
  backgroundEnabled?: boolean;
  /** Additional provider request headers. Common IPTV headers are also mapped to VLCKit options. */
  headers?: Record<string, string>;
  userAgent?: string;
  referrer?: string;
  cookies?: string;
  /** Target network buffer. Defaults to 1500 ms for VOD and 2500 ms for live streams. */
  networkCachingMs?: number;
  /** Time AVPlayer may remain unready before automatic VLCKit recovery. Defaults to 15 seconds. */
  connectionTimeoutSeconds?: number;
  live?: boolean;
}

export interface SeekOptions {
  seconds: number;
}

export interface TrackOptions {
  id: number;
}

export interface PlaybackSnapshot {
  engine?: ActivePlaybackEngine;
  state: 'idle' | 'loading' | 'playing' | 'paused' | 'buffering' | 'ended' | 'error';
  seconds: number;
  duration: number;
  attemptedEngines?: ActivePlaybackEngine[];
}

export interface PlaybackEvent extends PlaybackSnapshot {
  message?: string;
  errorCode?: 'invalid_url' | 'connection_timeout' | 'avplayer_failed' | 'vlc_failed';
  recoverable?: boolean;
}

export interface VistaStreamHybridPlayerPlugin {
  open(options: OpenOptions): Promise<{ engine: ActivePlaybackEngine }>;
  play(): Promise<void>;
  pause(): Promise<void>;
  seek(options: SeekOptions): Promise<void>;
  stop(): Promise<void>;
  getState(): Promise<PlaybackSnapshot>;
  selectAudioTrack(options: TrackOptions): Promise<void>;
  selectSubtitleTrack(options: TrackOptions): Promise<void>;
  addListener(eventName: 'stateChange' | 'progress' | 'exit', listener: (event: PlaybackEvent) => void): Promise<PluginListenerHandle>;
  removeAllListeners(): Promise<void>;
}
