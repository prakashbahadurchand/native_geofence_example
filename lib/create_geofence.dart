import 'package:flutter/material.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:native_geofence_example/callback.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateGeofence extends StatefulWidget {
  final VoidCallback? onGeofenceChanged;
  const CreateGeofence({super.key, this.onGeofenceChanged});

  @override
  CreateGeofenceState createState() => CreateGeofenceState();
}

class CreateGeofenceState extends State<CreateGeofence> {
  static const Location _timesSquare =
      Location(latitude: 27.7219375, longitude: 85.322578125);

  List<String> activeGeofences = [];
  late Geofence data;

  @override
  void initState() {
    super.initState();
    data = Geofence(
      id: 'zone1',
      location: _timesSquare,
      radiusMeters: 30,
      triggers: {
        GeofenceEvent.enter,
        GeofenceEvent.exit,
      },
      iosSettings: IosGeofenceSettings(
        initialTrigger: true,
      ),
      androidSettings: AndroidGeofenceSettings(
        initialTriggers: {GeofenceEvent.enter},
      ),
    );
    _updateRegisteredGeofences();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Active Geofences: ${activeGeofences.join(', ')}',
                style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 24),
            Form(
              child: Column(
                children: [
                  Text('Create/Remove Geofence',
                      style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'ID',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: data.id,
                    onChanged: (String value) =>
                        data = data.copyWith(id: () => value),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: data.location.latitude.toString(),
                          onChanged: (String value) => data = data.copyWith(
                            location: () => data.location
                                .copyWith(latitude: double.parse(value)),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: data.location.longitude.toString(),
                          onChanged: (String value) => data = data.copyWith(
                            location: () => data.location
                                .copyWith(longitude: double.parse(value)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Radius (meters)',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: data.radiusMeters.toString(),
                    onChanged: (String value) => data =
                        data.copyWith(radiusMeters: () => double.parse(value)),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.add_location_alt),
                          onPressed: () async {
                            if (!(await _checkPermissions())) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Lacking permissions!')),
                              );
                              return;
                            }
                            await NativeGeofenceManager.instance
                                .createGeofence(data, geofenceTriggered);
                            debugPrint('Geofence created: ${data.id}');
                            await _updateRegisteredGeofences();
                            await Future.delayed(const Duration(seconds: 1));
                            await _updateRegisteredGeofences();
                            widget.onGeofenceChanged?.call();
                          },
                          label: const Text('Register'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.remove_circle_outline),
                          onPressed: () async {
                            await NativeGeofenceManager.instance
                                .removeGeofence(data);
                            debugPrint('Geofence removed: ${data.id}');
                            await _updateRegisteredGeofences();
                            await Future.delayed(const Duration(seconds: 1));
                            await _updateRegisteredGeofences();
                            widget.onGeofenceChanged?.call();
                          },
                          label: const Text('Unregister'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateRegisteredGeofences() async {
    final List<String> geofences =
        await NativeGeofenceManager.instance.getRegisteredGeofenceIds();
    setState(() {
      activeGeofences = geofences;
    });
    debugPrint('Active geofences updated.');
  }
}

Future<bool> _checkPermissions() async {
  final locationPerm = await Permission.location.request();
  final backgroundLocationPerm = await Permission.locationAlways.request();
  final notificationPerm = await Permission.notification.request();
  return locationPerm.isGranted &&
      backgroundLocationPerm.isGranted &&
      notificationPerm.isGranted;
}

extension ModifyGeofence on Geofence {
  Geofence copyWith({
    String Function()? id,
    Location Function()? location,
    double Function()? radiusMeters,
    Set<GeofenceEvent> Function()? triggers,
    IosGeofenceSettings Function()? iosSettings,
    AndroidGeofenceSettings Function()? androidSettings,
  }) {
    return Geofence(
      id: id?.call() ?? this.id,
      location: location?.call() ?? this.location,
      radiusMeters: radiusMeters?.call() ?? this.radiusMeters,
      triggers: triggers?.call() ?? this.triggers,
      iosSettings: iosSettings?.call() ?? this.iosSettings,
      androidSettings: androidSettings?.call() ?? this.androidSettings,
    );
  }
}

extension ModifyLocation on Location {
  Location copyWith({
    double? latitude,
    double? longitude,
  }) {
    return Location(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

extension ModifyAndroidGeofenceSettings on AndroidGeofenceSettings {
  AndroidGeofenceSettings copyWith({
    Set<GeofenceEvent> Function()? initialTrigger,
    Duration Function()? expiration,
    Duration Function()? loiteringDelay,
    Duration Function()? notificationResponsiveness,
  }) {
    return AndroidGeofenceSettings(
      initialTriggers: initialTrigger?.call() ?? initialTriggers,
      expiration: expiration?.call() ?? this.expiration,
      loiteringDelay: loiteringDelay?.call() ?? this.loiteringDelay,
      notificationResponsiveness:
          notificationResponsiveness?.call() ?? this.notificationResponsiveness,
    );
  }
}
