import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';

import 'package:native_geofence/native_geofence.dart';
import 'package:native_geofence_example/notifications_repository.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> geofenceTriggered(GeofenceCallbackParams params) async {
  debugPrint('geofenceTriggered params: $params');
  final SendPort? send =
      IsolateNameServer.lookupPortByName('native_geofence_send_port');
  send?.send(params.event.name);

  // Play audio based on geofence event
  await _playGeofenceAudio(params.event);

  final notificationsRepository = NotificationsRepository();
  // TODO: Test to see what happens if we do not initialize the Notifications
  // plugin during callbacks.
  await notificationsRepository.init();

  final title =
      'Geofence ${capitalize(params.event.name)}: ${params.geofences.map((e) => e.id).join(', ')}';
  final message = 'Geofences:\n'
      '${params.geofences.map((e) => '• ID: ${e.id}, '
          'Radius=${e.radiusMeters.toStringAsFixed(0)}m, '
          'Triggers=${e.triggers.map((e) => e.name).join(',')}').join('\n')}\n'
      'Event: ${params.event.name}\n'
      'Location: ${params.location?.latitude.toStringAsFixed(5)}, '
      '${params.location?.longitude.toStringAsFixed(5)}';
  await notificationsRepository.showGeofenceTriggerNotification(title, message);

  await Future.delayed(const Duration(seconds: 1));
}

@pragma('vm:entry-point')
Future<void> _playGeofenceAudio(GeofenceEvent event) async {
  try {
    final player = AudioPlayer();

    // Configure for background playback
    await player.setAudioSource(
      event == GeofenceEvent.enter
          ? AudioSource.asset('assets/audios/enter_sound.mp3')
          : AudioSource.asset('assets/audios/exit_sound.mp3'),
    );

    // Play the audio
    await player.play();

    // Wait for audio to complete
    await player.positionStream.firstWhere(
      (position) => position >= (player.duration ?? Duration.zero),
    );

    // Dispose the player
    await player.dispose();

    debugPrint('Audio played for ${event.name} event');
  } catch (e) {
    debugPrint('Error playing audio: $e');
  }
}

String capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

// Call this during app startup
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    // ...add iOS if needed...
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

// Call this when a geofence event occurs
Future<void> showGeofenceNotification({
  required String title,
  required String description,
  required String imageUrl,
  required String soundAsset, // e.g., 'enter_sound.mp3' or 'exit_sound.mp3'
}) async {
  final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'geofence_channel',
    'Geofence Notifications',
    channelDescription: 'Notifications for geofence events',
    importance: Importance.max,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound(soundAsset.split('.').first),
    styleInformation: BigPictureStyleInformation(
      FilePathAndroidBitmap(imageUrl),
      contentTitle: title,
      summaryText: description,
    ),
  );
  final NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    // ...add iOS if needed...
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    description,
    platformChannelSpecifics,
  );
}

Future<void> showGeofenceNotificationWithSoundUrl({
  required String title,
  required String description,
  required String imageUrl,
  required String soundUrl, // URL to audio file
}) async {
  // Play audio from URL
  final player = AudioPlayer();
  player.setAudioSource(AudioSource.uri(Uri.parse(soundUrl)));
  await player.play();

  // Show notification (no custom sound, just default)
  final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'geofence_channel',
    'Geofence Notifications',
    channelDescription: 'Notifications for geofence events',
    importance: Importance.max,
    priority: Priority.high,
    // sound: null, // Use default or silent
    styleInformation: BigPictureStyleInformation(
      FilePathAndroidBitmap(imageUrl),
      contentTitle: title,
      summaryText: description,
    ),
  );
  final NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    // ...add iOS if needed...
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    description,
    platformChannelSpecifics,
  );
}

// NOTE: Audio playback from Dart code (like audioplayers) will NOT work if the app is terminated or removed from recent apps.
// This is a platform limitation: Dart isolates and plugins do not run when the app is killed.
// To play audio when the app is killed, you must implement native background services (Android: foreground service, iOS: background mode) in Kotlin/Java/Swift/ObjC.
// Flutter plugins like audioplayers and just_audio cannot play audio if the app is not running.

// NOTE: The audio_service package is designed for background audio playback and can run in the background (even when the app is in the background or screen is off).
// HOWEVER, on Android, if the app is fully terminated (swiped away from recents), neither Flutter nor audio_service can run Dart code.
// To play audio when the app is killed, you must implement a native Android foreground service in Kotlin/Java.
// audio_service can help with background playback while the app is running or in the background, but not when killed.

// Example usage with audio_service (for background, not terminated state):
// 1. Setup audio_service in your main.dart and background task.
// 2. In your geofence callback, trigger audio playback via audio_service's AudioHandler.

// This is a conceptual example for your callback:
Future<void> playAudioWithAudioService(String soundFilePath) async {
  // You must have initialized audio_service and registered an AudioHandler.
  // This will only work if the app is running or in the background, not killed.
  // Replace this with your actual AudioHandler call.
  // Example:
  // await audioHandler.playMediaItem(MediaItem(id: soundFilePath, ...));
}

Future<void> showGeofenceNotificationWithLocalFiles({
  required String title,
  required String description,
  required String imageFilePath,
  required String soundFilePath,
}) async {
  // Play audio using audio_service (background capable, but not if app is killed)
  try {
    await playAudioWithAudioService(soundFilePath);
  } catch (e) {
    debugPrint('Audio playback error: $e');
  }

  // Show notification with local image
  final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'geofence_channel',
    'Geofence Notifications',
    channelDescription: 'Notifications for geofence events',
    importance: Importance.max,
    priority: Priority.high,
    // sound: null, // Notification will use default sound or silent
    styleInformation: BigPictureStyleInformation(
      FilePathAndroidBitmap(imageFilePath),
      contentTitle: title,
      summaryText: description,
    ),
  );
  final NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    // ...add iOS if needed...
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    description,
    platformChannelSpecifics,
  );
}

// Example usage in your geofence callback:
void onGeofenceEvent(
    String eventType, String imageFilePath, String soundFilePath) async {
  if (eventType == 'enter') {
    await showGeofenceNotificationWithLocalFiles(
      title: 'Entered Zone',
      description: 'You have entered the geofence area.',
      imageFilePath:
          imageFilePath, // e.g. '/data/user/0/your.app/cache/enter.jpg'
      soundFilePath:
          soundFilePath, // e.g. '/data/user/0/your.app/cache/enter.mp3'
    );
  } else if (eventType == 'exit') {
    await showGeofenceNotificationWithLocalFiles(
      title: 'Exited Zone',
      description: 'You have exited the geofence area.',
      imageFilePath: imageFilePath,
      soundFilePath: soundFilePath,
    );
  }
}

// IMPORTANT: If you need audio to play even when the app is killed, you must:
// 1. Move audio playback logic to native Android code (Kotlin/Java) as a foreground service triggered by geofence events.
// 2. For iOS, use background modes and local notifications with custom sound (must be bundled in app).
// 3. Flutter cannot play audio in the background if the app is terminated.

// SUMMARY:
// - audio_service can play audio in the background (while app is running or backgrounded).
// - If the app is killed (terminated), only a native Android foreground service can play audio.
// - For true "play audio when app is killed", implement a native service in Kotlin/Java.
