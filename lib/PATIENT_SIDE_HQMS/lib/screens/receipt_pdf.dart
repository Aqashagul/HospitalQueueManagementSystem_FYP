import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Creates a one-page PDF receipt from a payments/{id} document.
class ReceiptPdf {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _dateTime(dynamic v) {
    if (v is! Timestamp) return '-';
    final t = v.toDate();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.day} ${_months[t.month - 1]} ${t.year}, $h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _money(num amount) {
    final digits = amount.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return 'Rs. $buf';
  }

  /// Hospital name from hospital/main (public read), with a fallback.
  static Future<String> _hospitalName() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('hospital')
          .doc('main')
          .get();
      final name = snap.data()?['name']?.toString() ?? '';
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return 'MediQueue Hospital';
  }

  static Future<Uint8List> build(Map<String, dynamic> data) async {
    final hospital = await _hospitalName();
    final status = data['status']?.toString() ?? '';
    final shownStatus = status == 'Used' ? 'Paid' : status;
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final emergency = data['type'] == 'emergency';
    final grey = PdfColors.grey700;

    pw.Widget row(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 11, color: grey),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '-' : value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                hospital,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                'Payment Receipt',
                style: pw.TextStyle(fontSize: 12, color: grey),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                data['receiptNo']?.toString() ?? '',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.grey400),
            row('Date', _dateTime(data['paidAt'] ?? data['createdAt'])),
            row('Patient', data['patientName']?.toString() ?? ''),
            row('Doctor', data['doctorName']?.toString() ?? ''),
            row('Department', data['department']?.toString() ?? ''),
            row('Token', data['token']?.toString() ?? ''),
            row('Payment method', 'Cash at reception'),
            row('Status', shownStatus),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Consultation fee',
                  style: pw.TextStyle(fontSize: 12, color: grey),
                ),
                pw.Text(
                  emergency ? 'No fee' : _money(amount),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                'This is a computer-generated receipt.',
                style: pw.TextStyle(fontSize: 9, color: grey),
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static String fileName(Map<String, dynamic> data) =>
      'Receipt_${data['receiptNo'] ?? 'payment'}';

  /// Downloads the PDF (web) / opens the share sheet (mobile).
  static Future<void> download(Map<String, dynamic> data) async {
    final bytes = await build(data);
    await Printing.sharePdf(bytes: bytes, filename: '${fileName(data)}.pdf');
  }
}
