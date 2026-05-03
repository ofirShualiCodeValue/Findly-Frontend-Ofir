import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Resolves the device's current coordinates after handling service-on
  /// and permission prompts. Returns null when the user denies permanently
  /// or location services are off — caller can fall back to manual entry.
  static Future<Position?> currentPosition() async {
    final servicesOn = await Geolocator.isLocationServiceEnabled();
    if (!servicesOn) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
