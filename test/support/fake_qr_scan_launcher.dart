import 'package:attendance/features/attendance/presentation/qr_scan_launcher.dart';
import 'package:flutter/widgets.dart';

/// Test double for the camera boundary. The screen returns either a payload,
/// null (employee backed out) or an error, exactly like the real launcher.
class FakeQrScanLauncher implements QrScanLauncher {
  FakeQrScanLauncher({this.payload, this.error});

  String? payload;
  Object? error;
  int calls = 0;

  @override
  Future<String?> scan(BuildContext context) async {
    calls++;
    if (error != null) throw error!;
    return payload;
  }
}
