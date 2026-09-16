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
}
export interface PlaybackEvent extends PlaybackSnapshot {
    message?: string;
}
export interface VistaStreamHybridPlayerPlugin {
    open(options: OpenOptions): Promise<{
        engine: ActivePlaybackEngine;
    }>;
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
//# sourceMappingURL=definitions.d.ts.map