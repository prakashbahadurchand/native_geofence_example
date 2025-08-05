import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:native_geofence_example/create_geofence.dart';

import 'notifications_repository.dart';

void main() => runApp(MyApp());

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
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      'native_geofence_send_port',
    );
    port.listen((dynamic data) {
      debugPrint('Event: $data');
      setState(() {
        geofenceState = data;
      });
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
                          child: Row(
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
