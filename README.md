# VistaStream Capacitor Hybrid Player

Native iOS playback for VistaStream. The plugin uses **AVPlayer first** for Apple-native HLS/MP4 playback, AirPlay, HDR and Picture-in-Picture, then automatically falls back to an embedded **MobileVLCKit** player for broader IPTV compatibility.

## Installation

```bash
npm install vistastream-capacitor-hybrid-player
npx cap sync ios
```

Version 0.2.0 requires Capacitor 6, CocoaPods, and iOS 15 or newer. Its native dependency is `MobileVLCKit ~> 3.4.0`.

## Usage

```ts
import { VistaStreamHybridPlayer } from 'vistastream-capacitor-hybrid-player';

await VistaStreamHybridPlayer.open({
  url: securePlaybackUrl,
  title: 'Movie title',
  startAt: 120,
  engine: 'auto',
  backgroundEnabled: true,
  live: false,
  headers: {
    Authorization: providerAuthorization,
    Origin: providerOrigin,
  },
  userAgent: providerUserAgent,
  referrer: providerReferrer,
  cookies: providerCookies,
  networkCachingMs: 1500,
  connectionTimeoutSeconds: 15,
});
```

Provider credentials and request metadata must only come from a source the user is authorized to access. Never log secrets or include them in analytics.

Supported commands include `play`, `pause`, `seek`, `stop`, `getState`, `selectAudioTrack`, and `selectSubtitleTrack`. The plugin emits `stateChange`, `progress`, and `exit` events.

## Compatibility and recovery

- HLS, MP4 and MOV begin with AVPlayer.
- MKV, AVI, MPEG-TS and WebM begin with MobileVLCKit.
- In automatic mode, an AVPlayer error or connection timeout switches to MobileVLCKit without leaving VistaStream.
- User-Agent, Referer, Cookie, network caching and reconnect behavior are forwarded to MobileVLCKit.
- Full provider headers are supplied to the AVFoundation asset.
- Playback happens directly between the user's device and provider; the plugin contains no IPTV service, credentials or content.
- Errors include the active engine and the engines already attempted.

No player can override expired accounts, provider outages, DRM, geo-restrictions, connection limits, or server-side account blocking.

## Native host requirements

For authorized providers that still use plain HTTP, the host application's iOS configuration must permit the required media transport under App Transport Security. Keep exceptions as narrow as the provider setup allows. Background audio also requires the host application capability.

## Roadmap

1. Validate CocoaPods, Swift compilation, direct HTTP providers and fallback behavior in a signed iPhone build.
2. Add a unified VistaStream control overlay for both engines.
3. Return complete audio and subtitle track lists.
4. Validate background playback and Picture-in-Picture per engine.
5. Add a TVVLCKit-backed tvOS target.

## Licensing

The plugin source is MIT licensed. MobileVLCKit is a separate dependency licensed under LGPL-2.1-or-later. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Applications distributing this plugin must satisfy VLCKit's license and attribution requirements.
