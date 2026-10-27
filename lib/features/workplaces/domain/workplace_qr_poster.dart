import 'dart:math' as math;
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Owner-printable workplace QR poster.
///
/// This is a pure builder: it takes the live payload plus the names to show and
/// returns the PDF bytes. Nothing here touches the network or a platform
/// plugin, so the layout is unit-testable; the actual print/save step lives in
/// `QrPdfExporter`.
class WorkplaceQrPosterData {
  const WorkplaceQrPosterData({
    required this.payload,
    required this.workplaceName,
    required this.organisationName,
    required this.generatedAt,
    this.appName = 'Attendly',
  });

  final String payload;
  final String workplaceName;
  final String organisationName;
  final DateTime generatedAt;
  final String appName;
}

/// `attendly-workplace-qr-main-shop.pdf` — stable, lowercase and filesystem
/// safe so repeated downloads do not pile up odd names.
String workplaceQrPosterFileName({
  required String workplaceName,
  String appName = 'Attendly',
}) {
  final slug = workplaceName
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  return '${appName.toLowerCase()}-workplace-qr-'
      '${slug.isEmpty ? 'workplace' : slug}.pdf';
}

Future<Uint8List> buildWorkplaceQrPoster(WorkplaceQrPosterData data) async {
  final document = pw.Document(
    title: '${data.appName} workplace QR - ${data.workplaceName}',
    author: data.appName,
    creator: data.appName,
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) => _poster(data),
    ),
  );

  return Uint8List.fromList(await document.save());
}

// Brand colours (mirrors lib/app/theme/app_colors.dart; the PDF cannot read
// Flutter theme tokens, so they are duplicated here deliberately).
final _ink = PdfColor.fromHex('#0F172A');
final _inkSoft = PdfColor.fromHex('#334155');
final _slate = PdfColor.fromHex('#64748B');
final _border = PdfColor.fromHex('#D8E4EC');
final _wash = PdfColor.fromHex('#F5F9FC');
final _emerald = PdfColor.fromHex('#047857');
final _emeraldWash = PdfColor.fromHex('#ECFDF5');
final _blue = PdfColor.fromHex('#2563EB');
final _teal = PdfColor.fromHex('#10B981');

pw.Widget _poster(WorkplaceQrPosterData data) {
  final workplace = _printable(data.workplaceName);
  final organisation = _printable(data.organisationName);
  final appName = _printable(data.appName);
  final issued = DateFormat('d MMMM yyyy').format(data.generatedAt.toLocal());

  return pw.Stack(
    children: [
      pw.Positioned.fill(child: pw.Container(color: PdfColors.white)),

      // Double frame: a confident navy rule with a fine emerald inner line.
      pw.Positioned.fill(
        child: pw.Container(
          margin: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _ink, width: 3),
          ),
        ),
      ),
      pw.Positioned.fill(
        child: pw.Container(
          margin: const pw.EdgeInsets.all(28),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _emerald, width: 0.8),
          ),
        ),
      ),

      // Corner ornaments sit on the inner frame so the border reads as
      // designed rather than as a plain page box.
      for (final corner in const [
        (28.0, 28.0, -1.0, -1.0),
        (28.0, 28.0, 1.0, -1.0),
        (28.0, 28.0, -1.0, 1.0),
        (28.0, 28.0, 1.0, 1.0),
      ])
        pw.Positioned(
          left: corner.$3 < 0 ? corner.$1 - 7 : null,
          right: corner.$3 > 0 ? corner.$1 - 7 : null,
          top: corner.$4 < 0 ? corner.$2 - 7 : null,
          bottom: corner.$4 > 0 ? corner.$2 - 7 : null,
          child: pw.Transform.rotate(
            angle: math.pi / 4,
            child: pw.Container(
              width: 14,
              height: 14,
              color: _emerald,
            ),
          ),
        ),

      pw.Positioned.fill(
        child: pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(62, 58, 62, 54),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _brandRow(appName),
              pw.SizedBox(height: 18),
              pw.Container(width: 54, height: 3, color: _emerald),
              pw.SizedBox(height: 22),
              pw.Text(
                'SCAN TO CHECK IN',
                style: pw.TextStyle(
                  color: _emerald,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2.2,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                workplace,
                style: pw.TextStyle(
                  color: _ink,
                  fontSize: 30,
                  fontWeight: pw.FontWeight.bold,
                  lineSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                organisation,
                style: pw.TextStyle(color: _slate, fontSize: 12.5),
              ),
              pw.SizedBox(height: 20),

              // QR card. The generous white padding is the quiet zone the
              // scanner needs; a tinted panel makes it the focal point.
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 22),
                decoration: pw.BoxDecoration(
                  color: _wash,
                  border: pw.Border.all(color: _border, width: 1),
                  borderRadius: pw.BorderRadius.circular(16),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(18),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: _border, width: 1),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.BarcodeWidget(
                        data: data.payload,
                        barcode: pw.Barcode.qrCode(
                          errorCorrectLevel:
                              BarcodeQRCorrectionLevel.medium,
                        ),
                        width: 268,
                        height: 268,
                        drawText: false,
                        color: _ink,
                      ),
                    ),
                    pw.SizedBox(height: 14),
                    pw.Text(
                      'Permanent workplace code',
                      style: pw.TextStyle(
                        color: _inkSoft,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),
              _steps(appName),
              pw.Spacer(),
              _footer(appName, issued),
            ],
          ),
        ),
      ),
    ],
  );
}

pw.Widget _brandRow(String appName) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(
        width: 40,
        height: 40,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
            colors: [_blue, _teal],
          ),
          borderRadius: pw.BorderRadius.circular(11),
        ),
        child: pw.Text(
          'A',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 23,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            appName,
            style: pw.TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            'ATTENDANCE, MADE SIMPLE',
            style: pw.TextStyle(
              color: _slate,
              fontSize: 7.5,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
      pw.Spacer(),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: pw.BoxDecoration(
          color: _emeraldWash,
          borderRadius: pw.BorderRadius.circular(20),
        ),
        child: pw.Text(
          'WORKPLACE POSTER',
          style: pw.TextStyle(
            color: _emerald,
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
      ),
    ],
  );
}

pw.Widget _steps(String appName) {
  final steps = [
    'Open the $appName app and sign in with your own account.',
    'Tap Scan QR and point your camera at this code.',
    'Stay inside the workplace area - your location is checked on the server.',
  ];
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
    decoration: pw.BoxDecoration(
      color: _emeraldWash,
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          pw.Padding(
            padding: pw.EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 17,
                  height: 17,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: _emerald,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Text(
                    '${i + 1}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 9),
                pw.Expanded(
                  child: pw.Text(
                    steps[i],
                    style: pw.TextStyle(
                      color: _inkSoft,
                      fontSize: 10.5,
                      lineSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

pw.Widget _footer(String appName, String issued) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Divider(color: _border, thickness: 1, height: 18),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              'Anyone who photographs this code can attempt a scan, but a punch '
              'still needs a signed-in employee, QR attendance enabled and a '
              'location inside the workplace area.',
              style: pw.TextStyle(color: _slate, fontSize: 7.8, lineSpacing: 1.6),
            ),
          ),
          pw.SizedBox(width: 18),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Issued $issued',
                style: pw.TextStyle(color: _inkSoft, fontSize: 8),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Replace it in $appName if it is shared',
                style: pw.TextStyle(color: _slate, fontSize: 7.5),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// The built-in PDF fonts are WinAnsi; user-supplied names may contain
/// characters they cannot draw. Normalise typographic punctuation and replace
/// anything outside Latin-1 so a poster never fails to generate.
String _printable(String input) {
  const replacements = {
    '\u2018': "'",
    '\u2019': "'",
    '\u201C': '"',
    '\u201D': '"',
    '\u2013': '-',
    '\u2014': '-',
    '\u2026': '...',
    '\u00A0': ' ',
  };
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final mapped = replacements[char] ?? char;
    for (final unit in mapped.runes) {
      buffer.write(unit <= 0xFF && unit >= 0x20 ? String.fromCharCode(unit) : '?');
    }
  }
  return buffer.toString().trim();
}
