import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('Notification clicked: ${response.payload}');
        },
      );

      await _requestPermissions();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    try {
      await Permission.notification.request();

      // For Android 13+ (API level 33+)
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (e) {
      print('Error requesting notification permissions: $e');
    }
  }

  static Future<void> showGeofenceNotification({
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? sound,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Geofence notifications',
        importance: Importance.high,
        priority: Priority.high,
        sound:
            sound != null ? RawResourceAndroidNotificationSound(sound) : null,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        fullScreenIntent: true,
        autoCancel: true,
        ongoing: false,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        ticker: title,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
        categoryIdentifier: 'geofence_category',
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  static Future<void> showGeofenceEnterNotification(String geofenceName) async {
    await showGeofenceNotification(
      title: '🎯 Geofence Entered',
      body: 'You have entered the $geofenceName area',
      channelId: 'geofence_enter',
      channelName: 'Geofence Enter Notifications',
      payload: 'enter:$geofenceName',
    );
  }

  static Future<void> showGeofenceExitNotification(String geofenceName) async {
    await showGeofenceNotification(
      title: '🚶 Geofence Exited',
      body: 'You have left the $geofenceName area',
      channelId: 'geofence_exit',
      channelName: 'Geofence Exit Notifications',
      payload: 'exit:$geofenceName',
    );
  }

  static Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      print('Error canceling notifications: $e');
    }
  }
}
