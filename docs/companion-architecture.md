# Narziss Companion Architecture

Narziss Companion is an independent native macOS client inside the Narziss repository. It does not change the browser extension runtime.

## Version 1 and 2 scope

- Always-on-top floating Narziss orb
- Expandable text chat panel
- Local assistant name, user name, personality, and voice settings
- API key storage in macOS Keychain
- OpenAI Realtime speech-to-speech over WebSocket
- 24 kHz mono PCM microphone capture and audio playback
- Push-to-talk from the UI or `Command + Shift + Space`
- Response cancellation and conversation truncation when interrupted

## Modules

- `NarzissCompanionCore`: profile, messages, and Realtime event decoding. This target has no UI dependencies and is unit tested.
- `CompanionViewModel`: conversation state machine and coordination between UI, audio, and network layers.
- `RealtimeClient`: ordered Realtime client-event delivery and server-event decoding.
- `AudioIO`: microphone conversion to 24 kHz PCM16 and incremental response playback.
- `CompanionWindowCoordinator`: floating pet panel, chat panel, menu bar item, and global hotkey.

## Security boundary

The OpenAI API key is stored as a generic password in the current user's macOS Keychain with `AfterFirstUnlockThisDeviceOnly` accessibility. Profile fields are stored in UserDefaults. No secrets are packaged into the app or release archive.

## Realtime interaction

The app disables server VAD and uses explicit push-to-talk:

1. Stop and truncate any current response.
2. Clear the input buffer and stream base64 PCM chunks.
3. Commit the buffer when the user finishes speaking.
4. Request a response and play `response.output_audio.delta` chunks.
5. Render input and output transcripts as chat messages.
