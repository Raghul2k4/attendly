import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../organisation/domain/organisation_models.dart';
import '../../organisation/presentation/organisation_providers.dart';
import '../../../core/widgets/surface_card.dart';
import '../domain/workplace_models.dart';
import 'widgets/workplace_map.dart';
import 'widgets/workplace_qr_card.dart';
import 'workplace_providers.dart';

/// Create/edit a workplace: map position, geofence radius, active state and
/// the printable QR code. The marker always starts from server data; nothing
/// is saved until the owner confirms.
class WorkplaceEditorScreen extends ConsumerWidget {
  const WorkplaceEditorScreen({super.key, this.workplaceId});

  final String? workplaceId;

  String get _title => workplaceId == null ? 'New workplace' : 'Edit workplace';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(myAccountProvider);

    return accountAsync.when(
      loading: () =>
          _shell(_title, const Center(child: CircularProgressIndicator())),
      error: (error, _) => _shell(
        _title,
        ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            AppErrorPanel(
              message: error is AppException
                  ? error.message
                  : 'We couldn’t load your organisation. Try again.',
              kind: error is AppException ? error.kind : AppErrorKind.unknown,
              onRetry: () => ref.invalidate(myAccountProvider),
            ),
          ],
        ),
      ),
      data: (account) {
        final organisation = account?.organisation;
        if (organisation == null) {
          return _shell(
            _title,
            ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                AppErrorPanel(
                  message:
                      'Your organisation isn’t available right now. Go back '
                      'and try again.',
                  kind: AppErrorKind.server,
                  onRetry: () => ref.invalidate(myAccountProvider),
                ),
              ],
            ),
          );
        }

        if (workplaceId == null) {
          return _EditorBody(organisation: organisation, existing: null);
        }

        final workplaces = ref.watch(workplacesProvider(organisation.id));
        return workplaces.when(
          loading: () =>
              _shell(_title, const Center(child: CircularProgressIndicator())),
          error: (error, _) => _shell(
            _title,
            ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                AppErrorPanel(
                  message: error is AppException
                      ? error.message
                      : 'We couldn’t load this workplace. Try again.',
                  kind: error is AppException
                      ? error.kind
                      : AppErrorKind.unknown,
                  onRetry: () =>
                      ref.invalidate(workplacesProvider(organisation.id)),
                ),
              ],
            ),
          ),
          data: (list) {
            Workplace? match;
            for (final workplace in list) {
              if (workplace.id == workplaceId) {
                match = workplace;
                break;
              }
            }
            if (match == null) {
              return _shell(
                _title,
                ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: const [
                    Text(
                      'This workplace no longer exists. It may have been '
                      'removed from another device.',
                    ),
                  ],
                ),
              );
            }
            return _EditorBody(
              key: ValueKey(match.id),
              organisation: organisation,
              existing: match,
            );
          },
        );
      },
    );
  }

  Widget _shell(String title, Widget child) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(child: child),
  );
}

class _EditorBody extends ConsumerStatefulWidget {
  const _EditorBody({
    super.key,
    required this.organisation,
    required this.existing,
  });

  final Organisation organisation;
  final Workplace? existing;

  @override
  ConsumerState<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends ConsumerState<_EditorBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _mapController = MapController();

  late final LatLng _initialCenter;
  late final double _initialZoom;
  LatLng? _point;
  late int _radius;
  late bool _isActive;

  bool _saving = false;
  AppException? _saveError;
  bool _locating = false;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _point = existing == null
        ? null
        : LatLng(existing.latitude, existing.longitude);
    _radius = existing?.radiusMeters ?? 100;
    _isActive = existing?.isActive ?? true;
    _initialCenter = _point ?? const LatLng(20, 0);
    _initialZoom = _point == null ? 2 : 17;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationMessage =
                'Turn on location services to use your current position. You '
                'can also tap the map.';
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationMessage =
                'Location permission was denied. You can still place the '
                'marker by tapping the map.';
          });
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationMessage =
                'Location permission is blocked. Enable it in Android settings, '
                'or tap the map to place the marker.';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _point = point);
      _mapController.move(point, 17);
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _locationMessage =
              'We couldn’t get a location fix. Move outdoors and try again, or '
              'tap the map.';
        });
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        setState(() {
          _locationMessage =
              'Location services are turned off. Turn them on, or tap the '
              'map.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationMessage =
              'We couldn’t read your position. Tap the map to place the marker '
              'instead.';
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final point = _point;
    if (point == null) {
      setState(() {
        _locationMessage =
            'Choose the location by tapping the map or using your current '
            'position.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final repository = ref.read(workplaceRepositoryProvider);
      if (widget.existing == null) {
        await repository.createWorkplace(
          organisationId: widget.organisation.id,
          name: _nameController.text,
          latitude: point.latitude,
          longitude: point.longitude,
          radiusMeters: _radius,
        );
      } else {
        await repository.updateWorkplace(
          organisationId: widget.organisation.id,
          workplaceId: widget.existing!.id,
          name: _nameController.text,
          latitude: point.latitude,
          longitude: point.longitude,
          radiusMeters: _radius,
          isActive: _isActive,
        );
      }
      ref.invalidate(workplacesProvider(widget.organisation.id));
      ref.invalidate(qrStatusesProvider(widget.organisation.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existing == null
                ? 'Workplace added'
                : 'Workplace changes saved',
          ),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saveError = error is AppException
              ? error
              : const AppException(
                  'We couldn’t save this workplace. Check your connection and '
                  'try again.',
                );
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final existing = widget.existing;
    final point = _point;

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'New workplace' : 'Edit workplace'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              Text(
                'Employees can check in only near this place.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Workplace name',
                controller: _nameController,
                validator: Validators.workplaceName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                enabled: !_saving,
              ),
              const SizedBox(height: AppSpacing.xl),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Location', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tap the map to place the marker at the entrance, or use '
                      'your current position.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    WorkplaceMap(
                      controller: _mapController,
                      point: point,
                      radiusMeters: _radius,
                      initialCenter: _initialCenter,
                      initialZoom: _initialZoom,
                      onPointSelected: (selected) {
                        setState(() {
                          _point = selected;
                          _locationMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _locating || _saving
                          ? null
                          : _useCurrentLocation,
                      icon: _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                      label: Text(
                        _locating
                            ? 'Getting your location…'
                            : 'Use my location',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      point == null
                          ? 'No location selected yet.'
                          : 'Selected: ${point.latitude.toStringAsFixed(6)}, '
                                '${point.longitude.toStringAsFixed(6)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: point == null
                            ? AppColors.amber600
                            : AppColors.ink600,
                      ),
                    ),
                    if (_locationMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: AppIconSize.sm,
                            color: AppColors.amber600,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _locationMessage!,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.amber600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your location is used once to place this marker. The '
                      'app never tracks you in the background.',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Check-in radius',
                            style: textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '$_radius m',
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.emerald700,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _radius.toDouble(),
                      min: 20,
                      max: 500,
                      divisions: 48,
                      label: '$_radius m',
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _radius = value.round()),
                    ),
                    Text(
                      'Employees must be within $_radius m of the marker when '
                      'they check in. A smaller radius is stricter; start with '
                      '100 m and adjust after testing at the workplace.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              if (existing != null) ...[
                const SizedBox(height: AppSpacing.lg),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile.adaptive(
                    value: _isActive,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _isActive = value),
                    title: const Text('Active workplace'),
                    subtitle: const Text(
                      'Inactive workplaces can’t be used for attendance. '
                      'Attendance history is kept.',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                WorkplaceQrCard(
                  organisationId: widget.organisation.id,
                  workplace: existing,
                ),
              ],
              if (_saveError != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppErrorPanel(
                  message: _saveError!.message,
                  kind: _saveError!.kind,
                  onRetry: _save,
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: SizedBox(
          width: double.infinity,
          child: AppPrimaryButton(
            label: existing == null ? 'Add workplace' : 'Save changes',
            onPressed: _save,
            inProgress: _saving,
          ),
        ),
      ),
    );
  }
}
