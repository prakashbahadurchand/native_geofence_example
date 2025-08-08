import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:native_geofence/native_geofence.dart';

class BackgroundGeofenceService {
  static const String _isolateName = 'geofence_isolate';
  static FlutterLocalNotificationsPlugin? _notificationsPlugin;

  static Future<void> initialize() async {
    await _initializeNotifications();
    await NativeGeofenceManager.instance.initialize();

    // Add a test geofence
    final zone1 = Geofence(
      id: 'test_geofence',
      location: Location(latitude: 37.7749, longitude: -122.4194),
      radiusMeters: 100,
      triggers: {
        GeofenceEvent.enter,
        GeofenceEvent.exit,
        GeofenceEvent.dwell,
      },
      iosSettings: IosGeofenceSettings(
        initialTrigger: true,
      ),
      androidSettings: AndroidGeofenceSettings(
        initialTriggers: {GeofenceEvent.enter, GeofenceEvent.exit},
        expiration: const Duration(days: 7),
        loiteringDelay: const Duration(minutes: 5),
        notificationResponsiveness: const Duration(minutes: 5),
      ),
    );

    await NativeGeofenceManager.instance
        .createGeofence(zone1, _geofenceCallback);
  }

  static Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notificationsPlugin!.initialize(settings);
  }

  @pragma('vm:entry-point')
  static Future<void> _geofenceCallback(GeofenceCallbackParams params) async {
    final SendPort? sendPort = IsolateNameServer.lookupPortByName(_isolateName);

    // Show notification for the first geofence (params.geofences is a List)
    await _showNotification(params.geofences.first.id, params.event);

    // Send data to main isolate if available
    sendPort?.send({
      'geofenceId': params.geofences.first.id,
      'location': params.location != null ? {
        'lat': params.location!.latitude,
        'lng': params.location!.longitude
      } : {
        'lat': params.geofences.first.location.latitude,
        'lng': params.geofences.first.location.longitude
      },
      'event': params.event.name,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> _showNotification(
      String geofenceId, GeofenceEvent event) async {
    // Initialize notifications if not already done
    if (_notificationsPlugin == null) {
      await _initializeNotifications();
    }

    const androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      channelDescription: 'Notifications for geofence events',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final eventText = event == GeofenceEvent.enter
        ? "entered"
        : event == GeofenceEvent.exit
            ? "exited"
            : "dwelling in";
    await _notificationsPlugin?.show(
      0,
      'Geofence Event',
      'You $eventText $geofenceId',
      details,
    );
  }

  static void setupPortReceiver(
      Function(Map<String, dynamic>) onGeofenceEvent) {
    final ReceivePort port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, _isolateName);

    port.listen((dynamic data) {
      if (data is Map<String, dynamic>) {
        onGeofenceEvent(data);
      }
    });
  }

  // Remove this method as NativeGeofence doesn't have requestLocationPermission
  // Use permission_handler package instead for requesting permissions
  static Future<void> requestPermissions() async {
    // You should use permission_handler package to request permissions
    // Example:
    // await Permission.location.request();
    // await Permission.locationAlways.request();
    throw UnimplementedError('Use permission_handler package to request location permissions');
  }

  static Future<void> removeAllGeofences() async {
    await NativeGeofenceManager.instance.removeAllGeofences();
  }

  static Future<List<ActiveGeofence>> getRegisteredGeofences() async {
    return await NativeGeofenceManager.instance.getRegisteredGeofences();
  }

  static Future<void> removeGeofenceById(String id) async {
    await NativeGeofenceManager.instance.removeGeofenceById(id);
  }
}
