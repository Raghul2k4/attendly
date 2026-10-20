/// Recoverable reasons the owner's current position could not be used for a
/// workplace marker. Each state owns the exact copy and the one useful action,
/// so the editor never leaves the owner with a dead end.
enum WorkplaceLocationIssue {
  permissionDenied,
  permissionBlocked,
  servicesDisabled,
  timeout,
  unknown;

  String get message => switch (this) {
    WorkplaceLocationIssue.permissionDenied =>
      'Location permission was not granted. Allow it to place the marker at '
          'your current position, or tap the map instead.',
    WorkplaceLocationIssue.permissionBlocked =>
      'Location permission is blocked. Allow it in Android settings, then try '
          'again, or tap the map instead.',
    WorkplaceLocationIssue.servicesDisabled =>
      'Location is turned off on this phone. Turn it on in Android location '
          'settings, then tap Use my location again.',
    WorkplaceLocationIssue.timeout =>
      'We could not get a fresh location fix. Move outdoors or near a window '
          'and try again, or tap the map instead.',
    WorkplaceLocationIssue.unknown =>
      'We could not read your position. Try again, or tap the map to place '
          'the marker manually.',
  };

  String? get actionLabel => switch (this) {
    WorkplaceLocationIssue.permissionBlocked => 'App settings',
    WorkplaceLocationIssue.servicesDisabled => 'Location settings',
    WorkplaceLocationIssue.permissionDenied ||
    WorkplaceLocationIssue.timeout ||
    WorkplaceLocationIssue.unknown => 'Try again',
  };

  bool get opensLocationSettings =>
      this == WorkplaceLocationIssue.servicesDisabled;

  bool get opensAppSettings => this == WorkplaceLocationIssue.permissionBlocked;
}
