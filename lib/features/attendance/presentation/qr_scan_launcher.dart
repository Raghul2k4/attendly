import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'qr_scanner_screen.dart';

/// Opens the camera and returns a scanned payload, or null when the employee
/// backs out. Injectable so attendance flow tests never need a camera.
abstract class QrScanLauncher {
  Future<String?> scan(BuildContext context);
}

class AppQrScanLauncher implements QrScanLauncher {
  const AppQrScanLauncher();

  @override
  Future<String?> scan(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const QrScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

final qrScanLauncherProvider = Provider<QrScanLauncher>(
  (ref) => const AppQrScanLauncher(),
);
