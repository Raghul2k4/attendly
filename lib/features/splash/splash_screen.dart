import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../core/widgets/brand_mark.dart';

/// Brief branded pause while the router resolves auth state; no artificial
/// delay — exits as soon as the auth state resolves.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: AppDurations.screen)
      ..forward();
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _rise = Tween(begin: 10.0, end: 0.0).animate(_fade);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: AnimatedBuilder(
            animation: _rise,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _rise.value),
              child: child,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 64),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Attendance',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Simple, honest attendance for small teams',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
