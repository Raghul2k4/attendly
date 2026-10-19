import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/utils/common_timezones.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/onboarding_scaffold.dart';
import 'organisation_providers.dart';

/// Owner onboarding step 1: create the organisation. Name and timezone are
/// the only required decisions; schedule and workplace settings follow later
/// with sensible server defaults.
class CreateOrganisationScreen extends ConsumerStatefulWidget {
  const CreateOrganisationScreen({super.key});

  @override
  ConsumerState<CreateOrganisationScreen> createState() =>
      _CreateOrganisationScreenState();
}

class _CreateOrganisationScreenState
    extends ConsumerState<CreateOrganisationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _timezone;
  bool _submitting = false;
  AppException? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final timezone =
          _timezone ?? ref.read(deviceTimezoneProvider).value ?? 'UTC';
      await ref
          .read(organisationRepositoryProvider)
          .createOrganisation(name: _nameController.text, timezone: timezone);
      ref.invalidate(myAccountProvider);
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) setState(() => _error = mapBackendError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickTimezone(String current) async {
    final deviceZone = ref.read(deviceTimezoneProvider).value;
    final zones = <String>{
      ...CommonTimezones.all,
      ?deviceZone,
      current,
    }.toList(growable: false)..sort();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TimezonePickerSheet(zones: zones, selected: current),
    );
    if (picked != null && mounted) setState(() => _timezone = picked);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detected = ref.watch(deviceTimezoneProvider).value ?? 'UTC';
    final timezone = _timezone ?? detected;

    return OnboardingScaffold(
      title: 'Create your business',
      subtitle: 'This is the name your team sees when they join.',
      bottom: AppPrimaryButton(
        label: 'Create business',
        onPressed: _submit,
        inProgress: _submitting,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Business name',
              controller: _nameController,
              validator: Validators.businessName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
            ),
            const SizedBox(height: AppSpacing.lg),
            _TimezoneField(
              value: timezone,
              onTap: _submitting ? null : () => _pickTimezone(timezone),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    color: AppColors.emerald700,
                    size: AppIconSize.md,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Free plan',
                          style: textTheme.titleSmall?.copyWith(
                            color: AppColors.emerald700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Up to 15 active staff. Change work hours, '
                          'attendance methods and locations later.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.emerald700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppErrorPanel(
                message: _error!.message,
                kind: _error!.kind,
                onRetry: _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimezoneField extends StatelessWidget {
  const _TimezoneField({required this.value, required this.onTap});

  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Timezone, $value. Tap to change.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Timezone',
            suffixIcon: Icon(Icons.unfold_more_rounded),
          ),
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}

/// Searchable IANA-zone list; the device zone may not be in the curated list,
/// so it is merged in before this sheet opens.
class _TimezonePickerSheet extends StatefulWidget {
  const _TimezonePickerSheet({required this.zones, required this.selected});

  final List<String> zones;
  final String selected;

  @override
  State<_TimezonePickerSheet> createState() => _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends State<_TimezonePickerSheet> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final zones = query.isEmpty
        ? widget.zones
        : widget.zones
              .where((zone) => zone.toLowerCase().contains(query))
              .toList(growable: false);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose a timezone',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Attendance days and late arrivals follow this timezone.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.slate500),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search, e.g. Kolkata or London',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              textInputAction: TextInputAction.search,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: zones.isEmpty
                  ? Center(
                      child: Text(
                        'No matching timezone.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.slate500),
                      ),
                    )
                  : ListView.builder(
                      itemCount: zones.length,
                      itemBuilder: (context, index) {
                        final zone = zones[index];
                        final selected = zone == widget.selected;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(zone),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.emerald600,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(zone),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
