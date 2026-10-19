import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/onboarding_scaffold.dart';
import 'organisation_providers.dart';

/// Employee onboarding: claim a membership with the one-time token the owner
/// shared. The server validates the hash, the plan limit and existing
/// memberships; the client never decides whether the claim is valid.
class JoinOrganisationScreen extends ConsumerStatefulWidget {
  const JoinOrganisationScreen({super.key});

  @override
  ConsumerState<JoinOrganisationScreen> createState() =>
      _JoinOrganisationScreenState();
}

class _JoinOrganisationScreenState
    extends ConsumerState<JoinOrganisationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  bool _submitting = false;
  AppException? _error;

  @override
  void dispose() {
    _tokenController.dispose();
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
      await ref
          .read(organisationRepositoryProvider)
          .claimMembership(
            Validators.normaliseInviteToken(_tokenController.text),
          );
      ref.invalidate(myAccountProvider);
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) setState(() => _error = mapBackendError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingScaffold(
      title: 'Join your team',
      subtitle:
          'Paste the invite token your business owner shared. The token '
          'works once and replaces any staff code you were given for setup.',
      bottom: AppPrimaryButton(
        label: 'Join organisation',
        onPressed: _submit,
        inProgress: _submitting,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Invite token',
              controller: _tokenController,
              validator: Validators.inviteToken,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'It looks like 20 letters and numbers, for example '
              'ABCD-EFGH-JKMN-PQRS-TUVW. Ask your owner if you can’t find it.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
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
