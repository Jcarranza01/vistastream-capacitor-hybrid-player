# VistaStream Capacitor Hybrid Player

Native iOS playback for VistaStream. The plugin uses **AVPlayer first** for HLS/MP4, AirPlay, HDR and Picture-in-Picture, then automatically falls back to **MobileVLCKit** for formats and streams AVFoundation cannot play.

## Status

This repository contains the first integration scaffold. It is not yet published to npm and has not yet been validated in a signed device build.

## Installation after npm publication

```bash
npm install vistastream-capacitor-hybrid-player
npx cap sync ios
```

The current native dependency is `MobileVLCKit ~> 3.4.0`. The host app must use CocoaPods and iOS 15 or newer.

## Usage

```ts
import { VistaStreamHybridPlayer } from 'vistastream-capacitor-hybrid-player';

await VistaStreamHybridPlayer.open({
  url: securePlaybackUrl,
  title: 'Movie title',
  startAt: 120,
  engine: 'auto',
  backgroundEnabled: true,
});

await VistaStreamHybridPlayer.addListener('progress', event => {
  console.log(event.engine, event.seconds, event.duration);
});
```

Supported commands include `play`, `pause`, `seek`, `stop`, `getState`, `selectAudioTrack`, and `selectSubtitleTrack`. The plugin emits `stateChange`, `progress`, and `exit` events.

## Engine policy

- HLS, MP4 and MOV begin with AVPlayer.
- MKV, AVI, MPEG-TS and WebM begin with VLCKit.
- In automatic mode, an AVPlayer failure switches to VLCKit without leaving VistaStream.
- The plugin never contains IPTV credentials or content. VistaStream supplies a short-lived playback URL.

## Roadmap

1. Validate CocoaPods and Swift compilation in a native iOS build.
2. Add a unified VistaStream control overlay for both engines.
3. Return complete audio and subtitle track lists.
4. Validate background playback and Picture-in-Picture per engine.
5. Add a TVVLCKit-backed tvOS target.
6. Publish the package to npm and connect it to the Floot project.

## Licensing

The plugin source is MIT licensed. MobileVLCKit is a separate dependency licensed under LGPL-2.1-or-later. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Applications distributing this plugin must satisfy VLCKit's license and attribution requirements.
