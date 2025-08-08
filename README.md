# native_geofence_example

Demonstrates how to use the native_geofence plugin with background audio playback.

## Setup

### Audio Assets

1. Create `assets/audios/` directory in your project root
2. Add your audio files:
   - `enter_sound.mp3` - Played when entering a geofence
   - `exit_sound.mp3` - Played when exiting a geofence

### Permissions

The app requires the following permissions:

- Location (always/background)
- Notifications
- Audio playback in background

### Important Notes

- Background audio works when the app is backgrounded but may not work when the app is completely terminated (removed from recent apps) due to platform limitations
- For guaranteed audio playback when the app is killed, native platform-specific implementations would be required
- iOS requires background audio capability and proper audio session configuration
- Android requires foreground service permissions for reliable background audio
