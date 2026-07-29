class SharedLocation {
  final double latitude;
  final double longitude;

  const SharedLocation({
    required this.latitude,
    required this.longitude,
  });
}

Future<SharedLocation> getCurrentLocation() {
  throw UnsupportedError(
    'Current-location sharing is not available on this device. '
    'Enter an address or Maps link instead.',
  );
}
