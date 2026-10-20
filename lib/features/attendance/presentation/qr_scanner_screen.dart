import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../domain/attendance_qr.dart';

/// Camera-first workplace scanner.
///
/// The scanner only checks the payload shape locally. The returned value is
/// still validated by `punch_attendance` (membership, live token, workplace,
/// geofence, accuracy and attendance state) before anything is recorded.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller;
  bool _handled = false;
  String? _invalidMessage;
  String? _lastRejectedValue;
  DateTime? _lastRejectedAt;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || !mounted) return;

    String? payload;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        payload = raw;
        break;
      }
    }
    if (payload == null) return;

    if (!isAttendanceQrPayload(payload)) {
      final now = DateTime.now();
      final previous = _lastRejectedAt;
      if (payload == _lastRejectedValue &&
          previous != null &&
          now.difference(previous) < const Duration(seconds: 4)) {
        return;
      }
      _lastRejectedValue = payload;
      _lastRejectedAt = now;
      unawaited(HapticFeedback.selectionClick());
      if (!mounted) return;
      setState(() {
        _invalidMessage =
            'That isn’t a workplace QR code. Point the camera at the printed '
            'Attendance code, or ask your owner for a current one.';
      });
      return;
    }

    setState(() {
      _handled = true;
      _invalidMessage = null;
    });
    unawaited(HapticFeedback.mediumImpact());
    try {
      await _controller.stop();
    } catch (_) {
      // The result still returns; disposal stops the camera if this fails.
    }
    if (!mounted) return;
    Navigator.of(context).pop(payload);
  }

  Future<void> _restartCamera() async {
    try {
      await _controller.start();
    } catch (_) {
      // The scanner renders its own camera error state.
    }
  }

  static Rect _scanWindow(Size size) {
    const topReserve = 116.0;
    const bottomReserve = 224.0;
    final availableHeight = math.max(
      140.0,
      size.height - topReserve - bottomReserve,
    );
    final side = math.min(size.width * .70, availableHeight);
    return Rect.fromCenter(
      center: Offset(size.width / 2, topReserve + availableHeight / 2),
      width: side,
      height: side,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink900,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text('Scan workplace QR'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final window = _scanWindow(constraints.biggest);
          return MobileScanner(
            controller: _controller,
            scanWindow: window,
            onDetect: _onDetect,
            placeholderBuilder: (_) => const ColoredBox(
              color: AppColors.ink900,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.surface),
              ),
            ),
            errorBuilder: (context, error) => _CameraError(
              error: error,
              onRetry: _restartCamera,
              onClose: () => Navigator.of(context).pop(),
            ),
            overlayBuilder: (context, _) => _ScannerOverlay(
              scanWindow: window,
              message: _invalidMessage,
              controller: _controller,
            ),
          );
        },
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({
    required this.scanWindow,
    required this.message,
    required this.controller,
  });

  final Rect scanWindow;
  final String? message;
  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    final shade = ColoredBox(color: Colors.black.withValues(alpha: .62));
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: scanWindow.top,
          child: shade,
        ),
        Positioned(
          left: 0,
          right: 0,
          top: scanWindow.bottom,
          bottom: 0,
          child: shade,
        ),
        Positioned(
          left: 0,
          top: scanWindow.top,
          width: scanWindow.left,
          height: scanWindow.height,
          child: shade,
        ),
        Positioned(
          left: scanWindow.right,
          right: 0,
          top: scanWindow.top,
          height: scanWindow.height,
          child: shade,
        ),
        Positioned.fromRect(
          rect: scanWindow,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.surface, width: 2.4),
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: math.max(scanWindow.top - AppSpacing.xxl, 88),
          child: Text(
            'Align the workplace QR inside the frame',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          bottom: 0,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: _ScannerInstructions(
              message: message,
              controller: controller,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannerInstructions extends StatelessWidget {
  const _ScannerInstructions({required this.message, required this.controller});

  final String? message;
  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.ink900.withValues(alpha: .90),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surface.withValues(alpha: .18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.emerald600,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.surface,
                  size: AppIconSize.md,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan the printed code',
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.surface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Usually posted at the entrance. Your location is checked '
                      'after the scan.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.surface.withValues(alpha: .72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.amber50,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
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
                      message!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.amber600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: _TorchButton(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final available =
            state.isRunning && state.torchState != TorchState.unavailable;
        final on = state.torchState == TorchState.on;
        return TextButton.icon(
          onPressed: available
              ? () {
                  unawaited(controller.toggleTorch());
                }
              : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.surface,
            disabledForegroundColor: AppColors.surface.withValues(alpha: .38),
            minimumSize: const Size(0, TouchTarget.minInteractive),
          ),
          icon: Icon(
            on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            size: AppIconSize.sm,
          ),
          label: Text(on ? 'Light on' : 'Light'),
        );
      },
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({
    required this.error,
    required this.onRetry,
    required this.onClose,
  });

  final MobileScannerException error;
  final Future<void> Function() onRetry;
  final VoidCallback onClose;

  bool get _permissionDenied =>
      error.errorCode == MobileScannerErrorCode.permissionDenied;

  bool get _unsupported =>
      error.errorCode == MobileScannerErrorCode.unsupported;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _permissionDenied
        ? 'Camera access is off'
        : _unsupported
        ? 'This phone can’t scan QR codes'
        : 'The camera couldn’t start';
    final body = _permissionDenied
        ? 'Allow camera access to scan the workplace QR. If app punching is '
              'enabled, you can still punch in from the home screen.'
        : _unsupported
        ? 'Use app punching if your owner has enabled it, or ask them to '
              'enable it for your team.'
        : 'Close other camera apps and try again. You can also ask your owner '
              'to enable app punching.';

    return ColoredBox(
      color: AppColors.ink900,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  size: 48,
                  color: AppColors.slate400,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.surface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.surface.withValues(alpha: .72),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton.icon(
                  onPressed: () {
                    unawaited(onRetry());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
                if (_permissionDenied) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () {
                      unawaited(Geolocator.openAppSettings());
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.surface,
                    ),
                    child: const Text('Open app settings'),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.surface.withValues(alpha: .72),
                  ),
                  child: const Text('Back to attendance'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
