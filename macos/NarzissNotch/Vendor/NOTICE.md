# MediaRemote adapter

Vendored from https://github.com/ungive/mediaremote-adapter at commit
`0e82bf1c44ec39554fbfc402ec88a48c6ae2a0fd`.
Copyright (c) 2025 Jonas van den Berg and contributors. BSD 3-Clause license;
see `mediaremote-adapter/LICENSE`. Source files are unmodified. Only the runtime
framework is compiled and bundled; the upstream test client is not used.

The adapter uses Apple's private MediaRemote framework through the upstream
Perl bridge. Supported sources are apps and websites that publish a macOS Now
Playing session, such as browser video, Music, Spotify, QuickTime, and podcasts.
An app or website that does not publish a session cannot be detected. Future
macOS changes may require updating this adapter.
