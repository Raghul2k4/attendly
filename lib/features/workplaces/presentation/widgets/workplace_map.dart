import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/utils/map_config.dart';

/// OpenStreetMap surface for choosing a workplace position and previewing its
/// check-in radius. The parent owns the selected point: tapping the map moves
/// the marker, and "use my location" recentres through the shared controller.
class WorkplaceMap extends StatefulWidget {
  const WorkplaceMap({
    super.key,
    required this.controller,
    required this.point,
    required this.radiusMeters,
    required this.initialCenter,
    required this.initialZoom,
    required this.onPointSelected,
  });

  final MapController controller;
  final LatLng? point;
  final int radiusMeters;
  final LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<LatLng> onPointSelected;

  @override
  State<WorkplaceMap> createState() => _WorkplaceMapState();
}

class _WorkplaceMapState extends State<WorkplaceMap> {
  bool _tileError = false;

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: widget.controller,
                options: MapOptions(
                  initialCenter: widget.initialCenter,
                  initialZoom: widget.initialZoom,
                  minZoom: 2,
                  maxZoom: 19,
                  backgroundColor: AppColors.slate200,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, selected) => widget.onPointSelected(selected),
                ),
                children: [
                  TileLayer(
                    urlTemplate: MapConfig.tileUrlTemplate,
                    userAgentPackageName: MapConfig.userAgentPackageName,
                    errorTileCallback: (tile, error, stackTrace) {
                      if (!_tileError && mounted) {
                        setState(() => _tileError = true);
                      }
                    },
                  ),
                  if (point != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: point,
                          radius: widget.radiusMeters.toDouble(),
                          useRadiusInMeter: true,
                          color: AppColors.emerald600.withValues(alpha: .12),
                          borderColor: AppColors.emerald600.withValues(
                            alpha: .55,
                          ),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  if (point != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 34,
                          height: 34,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.emerald600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x330F172A),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  MapConfig.attribution,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.ink600,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            if (_tileError)
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.amber50,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.amber600.withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: AppIconSize.sm,
                        color: AppColors.amber600,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Map tiles aren’t loading. You can still tap to place '
                          'the marker.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.amber600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
