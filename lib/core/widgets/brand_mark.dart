import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';

/// App mark: the brand illustration (a verified person inside a scan frame) on
/// a warm plate. The launcher icon is the simplified centre of this artwork —
/// see `tool/generate_icons.ps1` — so the splash and the home-screen icon read
/// as the same brand.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: AppColors.brandPlate,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/app_icon_source.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Attendance logo',
      ),
    );
  }
}
