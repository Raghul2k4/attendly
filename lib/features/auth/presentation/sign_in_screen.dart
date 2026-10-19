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
import 'auth_controller.dart';

/// Email/password sign-in. Failures are inline and specific; success is
/// confirmed by the server (router reacts to the auth stream, not local
/// optimistic state).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  AppException? _error;

  @override
  void dispose() {
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
    });

    try {
      await ref
          .read(authActionsProvider)
          .signIn(_emailController.text, _passwordController.text);
      // Router listens to authChanges and navigates; nothing to do here.
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingScaffold(
      title: 'Sign in',
      subtitle: 'Welcome back. Use the email you registered with.',
      bottom: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'New here?',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
          ),
          TextButton(
            onPressed: () => context.push('/sign-up', extra: null),
            child: const Text('Create an account'),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                autofillHints: const ['password'],
                enabled: !_submitting,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_error != null) ...[
                AppErrorPanel(
                  message: _error!.message,
                  kind: _error!.kind,
                  onRetry: _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppPrimaryButton(
                label: 'Sign in',
                onPressed: _submit,
                inProgress: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
