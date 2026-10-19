/// Map tile configuration.
///
/// The public OpenStreetMap tile servers are suitable for development and
/// small pilot use only; their usage policy does not cover production
/// traffic. Replace [tileUrlTemplate] with a contracted provider before
/// release (see docs/PLAN.md) — no code changes are needed beyond this file.
/// Attribution is required by the ODbL and must stay visible on the map.
abstract final class MapConfig {
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const String attribution = '© OpenStreetMap contributors';

  /// Sent as the HTTP User-Agent suffix, as required by the tile policy.
  static const String userAgentPackageName = 'com.techloft.attendance';
}
