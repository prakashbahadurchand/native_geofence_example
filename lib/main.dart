import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:native_geofence_example/create_geofence.dart';
import 'package:permission_handler/permission_handler.dart';

import 'callback.dart';
import 'notifications_repository.dart';
import 'services/background_geofence_service.dart';
import 'services/geofence_audio_service.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
void backgroundMain() {
  BackgroundGeofenceService.initialize();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services with error handling
  try {
    await NotificationService.init();
    await GeofenceAudioService.init();
    await _requestPermissions();
  } catch (e) {
    print('Error initializing services: $e');
  }

  // Initialize background geofence service
  BackgroundGeofenceService.initialize();
  BackgroundGeofenceService.setupPortReceiver((data) {
    print('Geofence event received: $data');
  });

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String geofenceState = 'N/A';
  ReceivePort port = ReceivePort();

  LatLng? _currentLocation;
  List<Geofence> _geofences = [];

  @override
  void initState() {
    super.initState();
    unawaited(NotificationsRepository().init());
    initializeNotifications();
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      'native_geofence_send_port',
    );
    port.listen((dynamic data) {
      debugPrint('Event: $data');
      setState(() {
        geofenceState = data;
      });

      // Handle geofence events with custom audio and notifications
      _handleGeofenceEvent(data);
    });
    initPlatformState();
    _getCurrentLocation();
    _loadGeofences();
  }

  Future<void> initPlatformState() async {
    debugPrint('Initializing...');
    await NativeGeofenceManager.instance.initialize();
    debugPrint('Initialization done');
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Failed to get location: $e');
    }
  }

  Future<void> _loadGeofences() async {
    final ids = await NativeGeofenceManager.instance.getRegisteredGeofenceIds();
    setState(() {
      _geofences = ids.contains('zone1')
          ? [
              Geofence(
                id: 'zone1',
                location:
                    Location(latitude: 27.7219375, longitude: 85.322578125),
                radiusMeters: 30,
                triggers: {GeofenceEvent.enter, GeofenceEvent.exit},
                iosSettings: IosGeofenceSettings(initialTrigger: true),
                androidSettings: AndroidGeofenceSettings(
                  initialTriggers: {GeofenceEvent.enter},
                ),
              )
            ]
          : [];
    });
  }

  void _onGeofenceChanged() {
    _loadGeofences();
  }

  void _handleGeofenceEvent(String data) async {
    try {
      if (data.contains('Enter')) {
        final geofenceId = _extractGeofenceId(data);
        await Future.wait([
          GeofenceAudioService.playEnterSound(),
          NotificationService.showGeofenceEnterNotification(geofenceId),
        ]);
      } else if (data.contains('Exit')) {
        final geofenceId = _extractGeofenceId(data);
        await Future.wait([
          GeofenceAudioService.playExitSound(),
          NotificationService.showGeofenceExitNotification(geofenceId),
        ]);
      }
    } catch (e) {
      print('Error handling geofence event: $e');
    }
  }

  String _extractGeofenceId(String data) {
    // Extract geofence ID from the event data string
    final parts = data.split(' ');
    return parts.length > 1 ? parts[1] : 'Unknown';
  }

  // Custom geofence callback for enter events
  @pragma('vm:entry-point')
  Future<void> geofenceEnterCallback(GeofenceCallbackParams params) async {
    print('Geofence entered: ${params.geofences.first.id}');
    try {
      await Future.wait([
        GeofenceAudioService.playEnterSound(),
        NotificationService.showGeofenceEnterNotification(
            params.geofences.first.id),
      ]);
    } catch (e) {
      print('Error in geofence enter callback: $e');
    }
  }

  Future<void> _addGeofence() async {
    try {
      final geofenceId =
          'test_geofence_${DateTime.now().millisecondsSinceEpoch}';
      final geofence = Geofence(
        id: geofenceId,
        location: Location(latitude: 37.7749, longitude: -122.4194),
        radiusMeters: 100.0,
        triggers: {GeofenceEvent.enter},
        iosSettings: IosGeofenceSettings(initialTrigger: true),
        androidSettings: AndroidGeofenceSettings(
          initialTriggers: {GeofenceEvent.enter, GeofenceEvent.exit},
        ),
      );

      // Create geofence with callback for enter events
      await NativeGeofenceManager.instance.createGeofence(
        geofence,
        geofenceEnterCallback,
      );

      await _loadGeofences();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geofence added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding geofence: $e')),
        );
      }
    }
  }

  Future<void> _startService() async {
    try {
      // Re-create geofences after reboot to ensure they're active
      await NativeGeofenceManager.instance.reCreateAfterReboot();

      setState(() {
        geofenceState = 'Service Running';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geofence service started!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting service: $e')),
        );
      }
    }
  }

  Future<void> _stopService() async {
    try {
      // Remove all geofences to effectively stop the service
      await NativeGeofenceManager.instance.removeAllGeofences();

      setState(() {
        geofenceState = 'Service Stopped';
        _geofences.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geofence service stopped!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping service: $e')),
        );
      }
    }
  }

  Future<void> _clearGeofences() async {
    try {
      await NativeGeofenceManager.instance.removeAllGeofences();

      setState(() {
        geofenceState = 'All geofences cleared';
        _geofences.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All geofences cleared!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing geofences: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    port.close();
    IsolateNameServer.removePortNameMapping('native_geofence_send_port');
    GeofenceAudioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native Geofence'),
          backgroundColor: Colors.indigo,
          actions: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _startService,
              tooltip: 'Start Service',
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopService,
              tooltip: 'Stop Service',
            ),
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearGeofences,
              tooltip: 'Clear All',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on, color: Colors.indigo),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Current geofence state: $geofenceState',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.music_note, color: Colors.green),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Audio Service: ${GeofenceAudioService.isInitialized ? "Ready" : "Initializing..."}',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      CreateGeofence(
                        onGeofenceChanged: _onGeofenceChanged,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _currentLocation ??
                        LatLng(27.7219375,
                            85.322578125), // fallback to Times Square
                    initialZoom: 14,
                    minZoom: 10,
                    maxZoom: 21,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.drag |
                          InteractiveFlag.flingAnimation |
                          InteractiveFlag.pinchMove |
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom,
                    ),
                    onTap: (_, __) => _getCurrentLocation(),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName:
                          'com.example.native_geofence_example',
                    ),
                    if (_currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 40,
                            height: 40,
                            child: Icon(Icons.my_location,
                                color: Colors.blue, size: 32),
                          ),
                        ],
                      ),
                    if (_geofences.isNotEmpty)
                      CircleLayer(
                        circles: _geofences
                            .map(
                              (g) => CircleMarker(
                                point: LatLng(
                                    g.location.latitude, g.location.longitude),
                                color: Colors.indigo.withOpacity(0.2),
                                borderStrokeWidth: 2,
                                borderColor: Colors.indigo,
                                radius: g.radiusMeters,
                              ),
                            )
                            .toList(),
                      ),
                    if (_geofences.isNotEmpty)
                      MarkerLayer(
                        markers: _geofences
                            .map(
                              (g) => Marker(
                                point: LatLng(
                                    g.location.latitude, g.location.longitude),
                                width: 40,
                                height: 40,
                                child: Icon(Icons.location_searching,
                                    color: Colors.indigo, size: 32),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await _getCurrentLocation();
            await _loadGeofences();
          },
          backgroundColor: Colors.indigo,
          child: Icon(Icons.refresh),
          tooltip: 'Refresh location & geofences',
        ),
      ),
    );
  }
}

// Move this function to the top level
Future<void> _requestPermissions() async {
  try {
    final permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.notification,
    ];

    for (final permission in permissions) {
      if (await permission.isDenied) {
        final result = await permission.request();
        if (result.isDenied) {
          print('${permission.toString()} permission denied');
        }
      }
    }
  } catch (e) {
    print('Error requesting permissions: $e');
  }
}
