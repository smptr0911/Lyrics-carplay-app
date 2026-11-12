# Architecture

The SwiftUI app owns a main-actor NowPlayingViewModel injected with MusicSource and LyricsProvider implementations. PlaybackCoordinator normalizes snapshots; LyricsCoordinator retrieves documents through a policy-aware in-memory cache. LyricsTimeline prepares stable sorted timestamps once per document and performs binary-search lookup. Track changes cancel stale lyric requests and clear highlighting. Missing position or mixed/static lines disable highlighting.

The demo is fully local. Polling is scoped to the root view task and cancelled when it ends. Production sources should use validated source events and reliable playback positions. Manual dragging suspends following until the user selects Follow lyrics. Apple Music artwork URLs and Spotify SDK artwork are rendered with late-response guards. Spotify and Apple Music adapters implement playback controls, while automatic follow resumption and background lyric behavior remain future work.
