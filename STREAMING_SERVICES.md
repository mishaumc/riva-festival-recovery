# Streaming Services and Protocols Reference

## 1. Google Cast (Chromecast built-in)

### How It Works
Sender app (phone/PC) discovers receiver (speaker) via mDNS. Sender launches a receiver app on the device and passes a media URL via protobuf over TLS. The receiver streams media directly from the internet.

### Technical Details
- **Discovery:** mDNS service `_googlecast._tcp.local` on port 5353
- **Control ports:** 8008 (HTTP), 8009 (HTTPS/TLS)
- **Protocol:** Protobuf over TLS 1.2, heartbeat every 5 seconds
- **Receiver app:** Chromium-based cast_shell with V8 JavaScript engine
- **Audio pipeline:** Media URL -> cast_shell -> ALSA -> speaker

### Common Issues
| Symptom | Cause | Fix |
|---------|-------|-----|
| Speaker not in Cast menu | mDNS blocked between Wi-Fi bands | Same band or IGMP Snooping |
| Connects but no audio (mobile) | V8 snapshot mismatch | Sync /system/chrome/ binaries |
| Connects but no audio (PC) | Firewall blocking 8009 | Allow outbound TCP 8009 |
| Disconnects after 10 seconds | Heartbeat timeout | Check network stability |
| setup_state=63 | Eureka config incomplete | Patch .eureka.conf |

### Compatible Apps
YouTube, Spotify, SoundCloud, Netflix, Chrome browser (tab cast), Plex, Tidal, Deezer, iHeartRadio, TuneIn

## 2. Apple AirPlay / AirPlay 2

### How It Works
Sender (iPhone/Mac) discovers receiver via mDNS/Bonjour. Audio is streamed via RTSP control channel and AES-encrypted RTP audio stream. AirPlay 2 adds multi-room sync via HomeKit.

### Technical Details
- **Discovery:** mDNS services `_airplay._tcp.local` and `_raop._tcp.local`
- **Ports:** 7000 (audio RTP), 7100 (control RTSP), 5000 (legacy)
- **Audio format:** ALAC (Apple Lossless) or AAC, 44.1 kHz, 16-bit
- **Encryption:** AES-128 with FairPlay key exchange
- **Implementation on RIVA:** Shairport-sync (open source)

### Common Issues
| Symptom | Cause | Fix |
|---------|-------|-----|
| Not visible in AirPlay menu | Bonjour not crossing subnets | Same subnet, enable multicast |
| Audio stuttering | Wi-Fi interference | Switch to 5 GHz or wired |
| AirPlay 2 not available | Device only supports AirPlay 1 | Hardware/firmware limitation |
| Pairing code required | AirPlay security enabled | Check speaker settings |

## 3. Spotify Connect

### How It Works
Spotify app acts as a remote control. The speaker streams audio directly from Spotify CDN using librespot or Spotify SDK. Discovery via mDNS and Spotify cloud relay.

### Technical Details
- **Discovery:** mDNS `_spotify-connect._tcp.local` + cloud relay
- **Authentication:** Zeroconf (local) or Spotify token (cloud)
- **Audio format:** Ogg Vorbis (160/320 kbps) or HE-AAC
- **Requirements:** Spotify Premium account
- **Implementation on RIVA:** Spotify SDK (proprietary)

### Common Issues
| Symptom | Cause | Fix |
|---------|-------|-----|
| Not in Spotify Devices list | mDNS blocked or cloud relay down | Same network, check internet |
| Authentication failed | Free account (Connect requires Premium) | Upgrade to Premium |
| Playback stops after 1 track | Zeroconf session expired | Restart Spotify app |
| Device shows but wont connect | librespot crash on speaker | Check speaker logs via SSH |

## 4. DLNA / UPnP

### How It Works
Three roles: DMS (server, e.g. NAS), DMC (controller, e.g. phone app), DMR (renderer, e.g. speaker). Controller tells renderer to play media from server via SOAP/HTTP.

### Technical Details
- **Discovery:** SSDP on UDP 1900, multicast 239.255.255.250
- **Control:** SOAP over HTTP (XML)
- **Media:** HTTP streaming (MP3, FLAC, WAV, AAC)
- **No DRM support**

### Common Issues
| Symptom | Cause | Fix |
|---------|-------|-----|
| Renderer not found | SSDP blocked by firewall/VLAN | Allow UDP 1900, same subnet |
| Unsupported format | Speaker codec limitation | Transcode to MP3/FLAC |
| No seek/pause | Renderer profile mismatch | Use compatible controller app |

### Compatible Apps
BubbleUPnP, mconnect, Plex, JRiver, foobar2000, VLC, Kodi

## 5. Tidal Connect

### How It Works
Similar to Spotify Connect. Tidal app is the remote, speaker streams from Tidal CDN. Requires Tidal HiFi or HiFi Plus subscription and certified device.

### Technical Details
- **Discovery:** mDNS `_tidal-connect._tcp.local`
- **Audio format:** FLAC (HiFi), MQA (HiFi Plus), AAC (standard)
- **Requirements:** Tidal HiFi subscription, certified device

### Common Issues
| Symptom | Cause | Fix |
|---------|-------|-----|
| Not in Tidal app | Device not Tidal Connect certified | Check device compatibility list |
| MQA not decoding | Speaker lacks MQA decoder | Use HiFi (FLAC) instead |
| Authentication timeout | Network issue | Restart Tidal app and speaker |

## 6. Roon RAAT

### How It Works
Roon Core (server) streams bit-perfect audio to RAAT endpoints over TCP. Supports PCM up to 32/768 and DSD256.

### Technical Details
- **Discovery:** Proprietary Roon discovery on UDP 9003
- **Transport:** TCP with custom RAAT protocol
- **Audio:** PCM (up to 32-bit/768 kHz), DSD (DoP or native)
- **Requirements:** Roon subscription, Roon Bridge or Roon Ready device

### Common Issues
| Symptom | Cause | Fix |
|---------|-------|-----|
| Endpoint not found in Roon | Firewall blocking UDP 9003 | Allow Roon ports |
| Sample rate mismatch | Device limitation | Configure Roon to downsample |
| DSD playback fails | DoP vs native DSD | Switch DSD mode in Roon settings |

## 7. Snapcast (DIY Multi-Room)

### How It Works
Snapserver distributes synchronized audio to Snapclients over TCP. Open source, runs on Raspberry Pi and Linux devices.

### Technical Details
- **Discovery:** Avahi/mDNS `_snapcast._tcp.local`
- **Transport:** TCP (default port 1704)
- **Sync precision:** Sub-millisecond

### Common Issues
| Symptom | Cause | Fix |
|---------|-------|-----|
| Audio drift | Network jitter on Wi-Fi | Use wired Ethernet or increase buffer |
| Buffer underruns | Insufficient bandwidth | Reduce sample rate or buffer size |

## 8. Bluetooth Audio

### Technical Details
- **Profiles:** A2DP (stereo audio), AVRCP (remote control), HFP (hands-free calls)
- **Codecs (quality order):** SBC (baseline) < AAC < aptX < aptX HD < LDAC < LC3 (BT 5.2)
- **Range:** ~10 meters (Class 2), ~100 meters (Class 1)

### Common Issues
| Symptom | Cause | Fix |
|---------|-------|-----|
| Poor audio quality | SBC codec fallback | Force AAC/aptX in phone settings |
| Frequent dropouts | Wi-Fi/Bluetooth interference | Move devices closer, reduce Wi-Fi traffic |
| Cannot pair | Multipoint limit reached | Disconnect other Bluetooth devices |
| Latency with video | A2DP inherent delay | Use aptX Low Latency if supported |

## Protocol Comparison Matrix

| Feature | Cast | AirPlay | Spotify | DLNA | Tidal | Roon | Bluetooth |
|---------|------|---------|---------|------|-------|------|-----------|
| Discovery | mDNS | mDNS | mDNS+Cloud | SSDP | mDNS | UDP 9003 | BT pairing |
| Audio Quality | Up to 24/96 | ALAC 16/44.1 | Ogg 320k | Up to 24/192 | FLAC/MQA | PCM 32/768 | LDAC 24/96 |
| Multi-Room | Yes | Yes (v2) | Yes | No | Yes | Yes | No |
| DRM | Widevine | FairPlay | Spotify DRM | None | Tidal DRM | None | None |
| Subscription | None | None | Premium | None | HiFi | Roon | None |
| RIVA Festival | Yes | Yes | Yes | Yes | No | No | Yes |

## Diagnostic Flowchart

1. **Which app are you using?** -> Identifies the protocol
2. **Can the app see the speaker?** -> Discovery issue (mDNS/SSDP/network)
3. **Can it connect but no audio?** -> Codec/DRM/pipeline issue
4. **Does it work then stop?** -> Session/timeout issue
5. **Does it work from PC but not phone?** -> V8 mismatch (Cast) or network band issue
