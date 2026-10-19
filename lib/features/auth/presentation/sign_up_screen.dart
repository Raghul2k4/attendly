import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_panel.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/onboarding_scaffold.dart';
import '../../onboarding/domain/user_role.dart';
import 'auth_controller.dart';

/// Email/password registration. `role` is onboarding context from the
/// welcome screen; server policies define what each account can actually do.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.role = UserRole.owner});

  final UserRole role;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  AppException? _error;
  bool _verifyNotice = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
      _verifyNotice = false;
    });

    try {
      final outcome = await ref
          .read(authActionsProvider)
          .signUp(
            fullName: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (mounted && outcome.needsEmailVerification) {
        setState(() {
          _verifyNotice = true;
          _submitting = false;
        });
        return;
      }
      // Session established — router redirect handles navigation.
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      // Reaches verification path too — notice keeps the button disabled.
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingScaffold(
      title: 'Create your account',
      subtitle: widget.role.signUpSubtitle,
      bottom: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already registered?',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
          ),
          TextButton(
            onPressed: () => context.push('/sign-in'),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Full name',
              controller: _nameController,
              validator: Validators.fullName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Email',
              controller: _emailController,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const ['email'],
              enabled: !_submitting,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Password',
              controller: _passwordController,
              validator: Validators.password,
              obscure: true,
              textInputAction: TextInputAction.done,
              autofillHints: const ['newPassword'],
              enabled: !_submitting,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_verifyNotice)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.emerald600.withValues(alpha: .3),
                  ),
                ),
                child: Text(
                  'Account created. Check your inbox for the verification '
                  'link, then sign in to continue.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.emerald700,
                  ),
                ),
              )
            else if (_error != null) ...[
              AppErrorPanel(
                message: _error!.message,
                kind: _error!.kind,
                onRetry: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Create account',
              onPressed: _verifyNotice ? null : _submit,
              inProgress: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}
