import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';

/// App mark: emerald rounded square with a white check — used on splash,
/// welcome and empty states. Text (wordmark) is composed by callers.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.emerald600,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.done_all_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}
