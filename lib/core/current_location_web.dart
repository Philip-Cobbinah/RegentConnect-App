// ignore: deprecated_member_use
import 'dart:html' as html;

class SharedLocation {
  final double latitude;
  final double longitude;

  const SharedLocation({
    required this.latitude,
    required this.longitude,
  });
}

Future<SharedLocation> getCurrentLocation() async {
  final position = await html.window.navigator.geolocation.getCurrentPosition(
    enableHighAccuracy: true,
    timeout: const Duration(seconds: 20),
  );
  final latitude = position.coords?.latitude?.toDouble();
  final longitude = position.coords?.longitude?.toDouble();
  if (latitude == null || longitude == null) {
    throw Exception('The browser did not return a valid location.');
  }
  return SharedLocation(latitude: latitude, longitude: longitude);
}
