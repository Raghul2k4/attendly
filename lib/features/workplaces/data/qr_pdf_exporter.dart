import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// Hands a finished poster to the platform.
///
/// `layoutPdf` opens Android's print sheet, which contains the "Save as PDF"
/// destination — so one action covers both downloading a PDF and printing it at
/// the workplace. Kept behind an interface so widget tests can assert the
/// action without a platform channel.
abstract class QrPdfExporter {
  Future<void> saveOrPrint({required Uint8List bytes, required String filename});
}

class PrintingQrPdfExporter implements QrPdfExporter {
  const PrintingQrPdfExporter();

  @override
  Future<void> saveOrPrint({
    required Uint8List bytes,
    required String filename,
  }) => Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
}

final qrPdfExporterProvider = Provider<QrPdfExporter>(
  (ref) => const PrintingQrPdfExporter(),
);
