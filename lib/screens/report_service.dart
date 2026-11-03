// >>> ADMIN APP. New file, e.g. lib/screens/report_service.dart
//
// pubspec.yaml needs two packages (run `flutter pub add pdf printing`):
//   pdf: ^3.11.0
//   printing: ^5.13.0

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ---------------------------------------------------------------------------
// Report data
// ---------------------------------------------------------------------------

class DoctorReportRow {
  final String name;
  final String department;
  final int patients;
  final int completed;
  final int? avgConsultMin;
  final int collected;
  const DoctorReportRow({
    required this.name,
    required this.department,
    required this.patients,
    required this.completed,
    required this.avgConsultMin,
    required this.collected,
  });
}

class DepartmentReportRow {
  final String name;
  final int total;
  final int completed;
  final int? avgWaitMin;
  const DepartmentReportRow({
    required this.name,
    required this.total,
    required this.completed,
    required this.avgWaitMin,
  });
}

class PaymentReportRow {
  final String receipt;
  final String patient;
  final String doctor;
  final int fee;
  final String status;
  final bool emergency;
  final DateTime? date;
  const PaymentReportRow({
    required this.receipt,
    required this.patient,
    required this.doctor,
    required this.fee,
    required this.status,
    required this.emergency,
    required this.date,
  });
}

/// Everything one report needs (the screen and the PDF use the same object).
class ReportData {
  final DateTime from;
  final DateTime to;
  final String rangeLabel;
  final int days;

  // This period
  final int total;
  final int completed;
  final int cancelled;
  final int expired;
  final int active;
  final int? avgWaitMin;
  final int? avgConsultMin;
  final int completionPercent;
  final String peakHour; // e.g. "2 PM - 3 PM", or "-"
  final int collected; // cash received
  final int refunds;
  final int net; // collected - refunds
  final int emergencyCount;

  // Previous period (same length, right before this one)
  final DateTime prevFrom;
  final DateTime prevTo;
  final int prevTotal;
  final int prevCompleted;
  final int prevCancelled;
  final int prevExpired;
  final int? prevAvgWaitMin;
  final int prevNet;

  final List<DoctorReportRow> doctors;
  final List<DepartmentReportRow> departments;
  final List<PaymentReportRow> payments;

  const ReportData({
    required this.from,
    required this.to,
    required this.rangeLabel,
    required this.days,
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.expired,
    required this.active,
    required this.avgWaitMin,
    required this.avgConsultMin,
    required this.completionPercent,
    required this.peakHour,
    required this.collected,
    required this.refunds,
    required this.net,
    required this.emergencyCount,
    required this.prevFrom,
    required this.prevTo,
    required this.prevTotal,
    required this.prevCompleted,
    required this.prevCancelled,
    required this.prevExpired,
    required this.prevAvgWaitMin,
    required this.prevNet,
    required this.doctors,
    required this.departments,
    required this.payments,
  });
}

// ---------------------------------------------------------------------------
// Builder: turns raw Firestore maps into a ReportData
// ---------------------------------------------------------------------------

class ReportBuilder {
  /// A token older than this is Expired (same as QueueAdminService.validHours).
  static const int _validHours = 24;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${fmtDate(d)}, $h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  /// "Rs. 1,500"
  static String money(num amount) {
    final digits = amount.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return 'Rs. $buf';
  }

  /// Percent change from [prev] to [cur]. null when there is no previous
  /// value to compare with.
  static int? changePercent(num cur, num prev) {
    if (prev == 0) return null;
    return (((cur - prev) / prev) * 100).round();
  }

  static DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

  /// completed / cancelled / expired / waiting / in consultation.
  /// An old Waiting / In Consultation token counts as expired even before the
  /// admin sweep has closed it.
  static String statusOf(Map<String, dynamic> d) {
    final s = (d['status']?.toString() ?? '').toLowerCase();
    if (s == 'waiting' || s == 'in consultation') {
      final joined = _ts(d['joinedAt']);
      if (joined != null &&
          DateTime.now().difference(joined) > const Duration(hours: _validHours)) {
        return 'expired';
      }
    }
    return s;
  }

  static int? _avgMinutes(
    Iterable<Map<String, dynamic>> list,
    String startKey,
    String endKey,
  ) {
    int totalMs = 0;
    int count = 0;
    for (final d in list) {
      final a = _ts(d[startKey]);
      final b = _ts(d[endKey]);
      if (a == null || b == null) continue;
      final diff = b.difference(a).inMilliseconds;
      if (diff >= 0) {
        totalMs += diff;
        count++;
      }
    }
    if (count == 0) return null;
    return (totalMs / count / 60000).round();
  }

  static String _hourLabel(int h) {
    String one(int x) {
      final hh = x % 12 == 0 ? 12 : x % 12;
      return '$hh ${x % 24 >= 12 ? 'PM' : 'AM'}';
    }

    return '${one(h)} - ${one(h + 1)}';
  }

  static bool _isMoney(String s) =>
      s == 'Paid' || s == 'Used' || s == 'Refunded';

  /// [entries] and [payments] must already be limited to the period,
  /// [prevEntries] and [prevPayments] to the previous period.
  static ReportData build({
    required List<Map<String, dynamic>> entries,
    required List<Map<String, dynamic>> prevEntries,
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> prevPayments,
    required DateTime from,
    required DateTime to,
    required DateTime prevFrom,
    required DateTime prevTo,
    required String rangeLabel,
  }) {
    int count(List<Map<String, dynamic>> l, String s) =>
        l.where((d) => statusOf(d) == s).length;

    final completed = count(entries, 'completed');
    final cancelled = count(entries, 'cancelled');
    final expired = count(entries, 'expired');
    final finished = completed + cancelled + expired;
    final active = entries.length - finished;

    // Peak hour
    final hours = List<int>.filled(24, 0);
    for (final d in entries) {
      final t = _ts(d['joinedAt']);
      if (t != null) hours[t.hour]++;
    }
    var peak = -1;
    var peakCount = 0;
    for (var h = 0; h < 24; h++) {
      if (hours[h] > peakCount) {
        peakCount = hours[h];
        peak = h;
      }
    }

    // Money (cash only; emergency requests carry amount 0)
    int sumWhere(List<Map<String, dynamic>> l, bool Function(String) test) {
      var sum = 0;
      for (final p in l) {
        if (test(p['status']?.toString() ?? '')) {
          sum += (p['amount'] as num?)?.toInt() ?? 0;
        }
      }
      return sum;
    }

    final collected = sumWhere(payments, _isMoney);
    final refunds = sumWhere(payments, (s) => s == 'Refunded');
    final prevCollected = sumWhere(prevPayments, _isMoney);
    final prevRefunds = sumWhere(prevPayments, (s) => s == 'Refunded');

    final emergencyCount = payments.where((p) {
      final s = p['status']?.toString() ?? '';
      return p['type'] == 'emergency' && (s == 'Accepted' || s == 'Used');
    }).length;

    // Doctor-wise
    final byDoctor = <String, List<Map<String, dynamic>>>{};
    for (final d in entries) {
      final key = d['doctorId']?.toString() ?? '';
      byDoctor.putIfAbsent(key, () => []).add(d);
    }
    final doctorRows = <DoctorReportRow>[];
    byDoctor.forEach((id, list) {
      final done = list.where((d) => statusOf(d) == 'completed').toList();
      final fees = payments.where((p) {
        final s = p['status']?.toString() ?? '';
        return p['doctorId']?.toString() == id && (s == 'Paid' || s == 'Used');
      });
      var collectedByDoctor = 0;
      for (final p in fees) {
        collectedByDoctor += (p['amount'] as num?)?.toInt() ?? 0;
      }
      doctorRows.add(
        DoctorReportRow(
          name: list.first['doctorName']?.toString() ?? '-',
          department: list.first['department']?.toString() ?? '-',
          patients: list.length,
          completed: done.length,
          avgConsultMin: _avgMinutes(done, 'calledAt', 'completedAt'),
          collected: collectedByDoctor,
        ),
      );
    });
    doctorRows.sort((a, b) => b.patients.compareTo(a.patients));

    // Department-wise
    final byDept = <String, List<Map<String, dynamic>>>{};
    for (final d in entries) {
      final key = d['department']?.toString() ?? '-';
      byDept.putIfAbsent(key, () => []).add(d);
    }
    final deptRows = <DepartmentReportRow>[];
    byDept.forEach((name, list) {
      deptRows.add(
        DepartmentReportRow(
          name: name,
          total: list.length,
          completed: list.where((d) => statusOf(d) == 'completed').length,
          avgWaitMin: _avgMinutes(list, 'joinedAt', 'calledAt'),
        ),
      );
    });
    deptRows.sort((a, b) => b.total.compareTo(a.total));

    // Payment rows (confirmed payments only)
    final paymentRows = <PaymentReportRow>[];
    for (final p in payments) {
      final s = p['status']?.toString() ?? '';
      if (!(_isMoney(s) || s == 'Accepted')) continue;
      paymentRows.add(
        PaymentReportRow(
          receipt: p['receiptNo']?.toString() ?? '-',
          patient: p['patientName']?.toString() ?? '-',
          doctor: p['doctorName']?.toString() ?? '-',
          fee: (p['amount'] as num?)?.toInt() ?? 0,
          status: s == 'Used' ? 'Paid' : s,
          emergency: p['type'] == 'emergency',
          date: _ts(p['paidAt']) ?? _ts(p['createdAt']),
        ),
      );
    }
    paymentRows.sort((a, b) {
      final da = a.date ?? DateTime(2000);
      final db = b.date ?? DateTime(2000);
      return db.compareTo(da);
    });

    return ReportData(
      from: from,
      to: to,
      rangeLabel: rangeLabel,
      days: to.difference(from).inDays + 1,
      total: entries.length,
      completed: completed,
      cancelled: cancelled,
      expired: expired,
      active: active < 0 ? 0 : active,
      avgWaitMin: _avgMinutes(entries, 'joinedAt', 'calledAt'),
      avgConsultMin: _avgMinutes(
        entries.where((d) => statusOf(d) == 'completed'),
        'calledAt',
        'completedAt',
      ),
      completionPercent:
          finished == 0 ? 0 : ((completed / finished) * 100).round(),
      peakHour: peak < 0 ? '-' : _hourLabel(peak),
      collected: collected,
      refunds: refunds,
      net: collected - refunds,
      emergencyCount: emergencyCount,
      prevFrom: prevFrom,
      prevTo: prevTo,
      prevTotal: prevEntries.length,
      prevCompleted: count(prevEntries, 'completed'),
      prevCancelled: count(prevEntries, 'cancelled'),
      prevExpired: count(prevEntries, 'expired'),
      prevAvgWaitMin: _avgMinutes(prevEntries, 'joinedAt', 'calledAt'),
      prevNet: prevCollected - prevRefunds,
      doctors: doctorRows,
      departments: deptRows,
      payments: paymentRows,
    );
  }
}

// ---------------------------------------------------------------------------
// PDF
// ---------------------------------------------------------------------------

class ReportPdf {
  static String _min(int? v) => v == null ? '-' : '$v min';

  static String _change(num cur, num? prev) {
    if (prev == null) return '-';
    final c = ReportBuilder.changePercent(cur, prev);
    if (c == null) return '-';
    return c > 0 ? '+$c%' : '$c%';
  }

  static String fileName(ReportData r) {
    String k(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    return 'MediQueue_Report_${k(r.from)}_${k(r.to)}';
  }

  static Future<Uint8List> build(
    ReportData r, {
    required String hospital,
    required String generatedBy,
  }) async {
    final doc = pw.Document();
    final generatedOn = ReportBuilder.fmtDateTime(DateTime.now());
    final period =
        '${ReportBuilder.fmtDate(r.from)} - ${ReportBuilder.fmtDate(r.to)}';
    final prevPeriod =
        '${ReportBuilder.fmtDate(r.prevFrom)} - ${ReportBuilder.fmtDate(r.prevTo)}';

    final grey = PdfColors.grey700;

    pw.Widget heading(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        );

    pw.Widget table(List<String> headers, List<List<String>> rows,
        {Map<int, pw.Alignment>? align}) {
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: .5),
          bottom: pw.BorderSide(color: PdfColors.grey400, width: .5),
        ),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        cellAlignments: align,
      );
    }

    final right = pw.Alignment.centerRight;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 36),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: .5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by $generatedBy on $generatedOn',
                style: pw.TextStyle(fontSize: 8, color: grey),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: grey),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          // ---- Title block ----
          pw.Text(
            hospital,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Queue & Payments Report',
            style: pw.TextStyle(fontSize: 13, color: grey),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Report period: ${r.rangeLabel} ($period)',
              style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Compared with: $prevPeriod',
              style: pw.TextStyle(fontSize: 9, color: grey)),
          pw.Divider(color: PdfColors.grey400),

          // ---- 1. Summary ----
          heading('1. Summary'),
          table(
            ['Metric', 'This period', 'Previous period', 'Change'],
            [
              ['Total tokens', '${r.total}', '${r.prevTotal}', _change(r.total, r.prevTotal)],
              ['Completed', '${r.completed}', '${r.prevCompleted}', _change(r.completed, r.prevCompleted)],
              ['Cancelled', '${r.cancelled}', '${r.prevCancelled}', _change(r.cancelled, r.prevCancelled)],
              ['Expired', '${r.expired}', '${r.prevExpired}', _change(r.expired, r.prevExpired)],
              [
                'Average waiting time',
                _min(r.avgWaitMin),
                _min(r.prevAvgWaitMin),
                r.avgWaitMin == null || r.prevAvgWaitMin == null
                    ? '-'
                    : _change(r.avgWaitMin!, r.prevAvgWaitMin),
              ],
              ['Average consultation time', _min(r.avgConsultMin), '-', '-'],
              ['Completion rate', '${r.completionPercent}%', '-', '-'],
              ['Busiest hour', r.peakHour, '-', '-'],
              ['Net collection', ReportBuilder.money(r.net), ReportBuilder.money(r.prevNet), _change(r.net, r.prevNet)],
            ],
            align: {1: right, 2: right, 3: right},
          ),

          // ---- 2. Doctor-wise ----
          heading('2. Doctor-wise report'),
          if (r.doctors.isEmpty)
            pw.Text('No data for this period.', style: pw.TextStyle(fontSize: 9, color: grey))
          else
            table(
              ['Doctor', 'Department', 'Patients', 'Completed', 'Avg consult', 'Fee collected'],
              [
                for (final d in r.doctors)
                  [
                    d.name,
                    d.department,
                    '${d.patients}',
                    '${d.completed}',
                    _min(d.avgConsultMin),
                    ReportBuilder.money(d.collected),
                  ],
              ],
              align: {2: right, 3: right, 4: right, 5: right},
            ),

          // ---- 3. Department-wise ----
          heading('3. Department-wise summary'),
          if (r.departments.isEmpty)
            pw.Text('No data for this period.', style: pw.TextStyle(fontSize: 9, color: grey))
          else
            table(
              ['Department', 'Total patients', 'Completed', 'Avg waiting'],
              [
                for (final d in r.departments)
                  [d.name, '${d.total}', '${d.completed}', _min(d.avgWaitMin)],
              ],
              align: {1: right, 2: right, 3: right},
            ),

          // ---- 4. Payments ----
          heading('4. Payments'),
          pw.Text(
            'Cash collected: ${ReportBuilder.money(r.collected)}    '
            'Refunds: ${ReportBuilder.money(r.refunds)}    '
            'Net: ${ReportBuilder.money(r.net)}    '
            'Emergency (no fee): ${r.emergencyCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 6),
          if (r.payments.isEmpty)
            pw.Text('No payments in this period.', style: pw.TextStyle(fontSize: 9, color: grey))
          else
            table(
              ['Receipt', 'Date', 'Patient', 'Doctor', 'Fee', 'Status'],
              [
                for (final p in r.payments)
                  [
                    p.receipt,
                    ReportBuilder.fmtDateTime(p.date),
                    p.patient,
                    p.doctor,
                    p.emergency ? 'No fee' : ReportBuilder.money(p.fee),
                    p.status,
                  ],
              ],
              align: {4: right},
            ),

          // ---- Signatures ----
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              for (final label in ['Prepared by', 'Approved by'])
                pw.Container(
                  width: 180,
                  padding: const pw.EdgeInsets.only(top: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600, width: .6)),
                  ),
                  child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: grey)),
                ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Opens the print dialog.
  static Future<void> printReport(
    ReportData r, {
    required String hospital,
    required String generatedBy,
  }) {
    return Printing.layoutPdf(
      name: fileName(r),
      onLayout: (_) => build(r, hospital: hospital, generatedBy: generatedBy),
    );
  }

  /// Downloads the PDF (web) / opens the share sheet (mobile).
  static Future<void> download(
    ReportData r, {
    required String hospital,
    required String generatedBy,
  }) async {
    final bytes = await build(r, hospital: hospital, generatedBy: generatedBy);
    await Printing.sharePdf(bytes: bytes, filename: '${fileName(r)}.pdf');
  }
}