import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class GeofenceAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  GeofenceAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    try {
      // Initialize audio session
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      _audioPlayer.playerStateStream.listen((state) {
        final isPlaying = state.playing;
        final processingState = state.processingState;

        playbackState.add(PlaybackState(
          controls: [
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1],
          processingState: _getAudioServiceProcessingState(processingState),
          playing: isPlaying,
          updatePosition: _audioPlayer.position,
          bufferedPosition: _audioPlayer.bufferedPosition,
          speed: _audioPlayer.speed,
          queueIndex: 0,
        ));
      });

      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio handler: $e');
    }
  }

  AudioProcessingState _getAudioServiceProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  Future<void> playGeofenceAudio(
      String assetPath, String title, String artist) async {
    if (!_isInitialized) {
      await _init();
    }

    try {
      final mediaItem = MediaItem(
        id: assetPath,
        title: title,
        artist: artist,
        duration: Duration.zero,
        artUri: null,
      );

      this.mediaItem.add(mediaItem);

      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
    } catch (e) {
      print('Error playing geofence audio: $e');
    }
  }

  @override
  Future<void> play() async => _audioPlayer.play();

  @override
  Future<void> pause() async => _audioPlayer.pause();

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => _audioPlayer.seek(position);

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'dispose':
        await _audioPlayer.dispose();
        break;
    }
  }
}

class GeofenceAudioService {
  static GeofenceAudioHandler? _audioHandler;
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      _audioHandler = await AudioService.init(
        builder: () => GeofenceAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.geofence_audio',
          androidNotificationChannelName: 'Geofence Audio Service',
          androidNotificationOngoing: false,
          androidShowNotificationBadge: true,
          androidNotificationClickStartsActivity: true,
          androidNotificationIcon: 'drawable/ic_notification',
          androidStopForegroundOnPause: true,
          artDownscaleHeight: 64,
          artDownscaleWidth: 64,
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
        ),
      );
      _isInitialized = true;
    } catch (e) {
      print('Error initializing audio service: $e');
    }
  }

  static Future<void> playEnterSound() async {
    if (!_isInitialized) await init();

    try {
      await _audioHandler?.playGeofenceAudio(
        'assets/audio/geofence_enter.mp3',
        'Geofence Entered',
        'Location Alert',
      );
    } catch (e) {
      print('Error playing enter sound: $e');
    }
  }

  static Future<void> playExitSound() async {
    if (!_isInitialized) await init();

    try {
      await _audioHandler?.playGeofenceAudio(
        'assets/audio/geofence_exit.mp3',
        'Geofence Exited',
        'Location Alert',
      );
    } catch (e) {
      print('Error playing exit sound: $e');
    }
  }

  static Future<void> dispose() async {
    try {
      await _audioHandler?.customAction('dispose');
      await _audioHandler?.stop();
      _audioHandler = null;
      _isInitialized = false;
    } catch (e) {
      print('Error disposing audio service: $e');
    }
  }

  static bool get isInitialized => _isInitialized;
}
