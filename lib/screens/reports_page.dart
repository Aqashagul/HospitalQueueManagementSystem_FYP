import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/screens/queue_admin_service.dart';
import 'package:queue_management_system/screens/report_service.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/analytics_data.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/completed_vs_cancelled_chart.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/doctor_overload_chart.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/patients_by_department.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/peak_hour_chart.dart';
import 'package:queue_management_system/widgets/reports_and_analytics/weekly_patient_flow_chart.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/live_date_time_widget.dart';
import 'package:queue_management_system/widgets/resuable/rounded_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// >>> ADMIN APP. Replaces your ReportsPage file.
// Extra imports needed at the top (besides your existing ones):
//   import 'package:cloud_firestore/cloud_firestore.dart';
//   import 'package:firebase_auth/firebase_auth.dart';
//   import 'report_service.dart';   // adjust the path

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const List<String> _ranges = [
    "Today",
    "Yesterday",
    "Last 7 Days",
    "Last 30 Days",
    "This Month",
    "Custom Range",
  ];

  // A custom range can be at most this many days (keeps Firestore reads low).
  static const int _maxCustomDays = 90;

  // Currently selected date-range filter. It decides which days of queue
  // entries the stat cards, the charts and the report are calculated from.
  String selectedRange = "Last 7 Days";
  DateTimeRange? _customRange;

  final QueueAdminService _service = QueueAdminService();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _paymentStream;

  // Used in the printed report.
  String _hospitalName = 'MediQueue Hospital';
  String _adminName = 'Admin';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
    _paymentStream = _buildPaymentStream();
    _loadReportInfo();
  }

  Future<void> _loadReportInfo() async {
    try {
      final db = FirebaseFirestore.instance;
      final hospital = await db.collection('hospital').doc('main').get();
      final name = hospital.data()?['name']?.toString() ?? '';
      if (name.isNotEmpty) _hospitalName = name;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await db.collection('users').doc(user.uid).get();
        final who = profile.data()?['name']?.toString() ?? '';
        _adminName = who.isNotEmpty ? who : (user.email ?? 'Admin');
      }
    } catch (_) {
      // The report still works with the default names.
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // First day (inclusive) of the selected range.
  DateTime _rangeStart() {
    final now = DateTime.now();
    final today = _today();
    switch (selectedRange) {
      case "Today":
        return today;
      case "Yesterday":
        return today.subtract(const Duration(days: 1));
      case "Last 30 Days":
        return today.subtract(const Duration(days: 29));
      case "This Month":
        return DateTime(now.year, now.month, 1);
      case "Custom Range":
        return _customRange != null
            ? _dateOnly(_customRange!.start)
            : today.subtract(const Duration(days: 6));
      case "Last 7 Days":
      default:
        return today.subtract(const Duration(days: 6));
    }
  }

  // Last day (inclusive) of the selected range.
  DateTime _rangeEnd() {
    switch (selectedRange) {
      case "Yesterday":
        return _today().subtract(const Duration(days: 1));
      case "Custom Range":
        return _customRange != null ? _dateOnly(_customRange!.end) : _today();
      default:
        return _today();
    }
  }

  // How many days the selected range covers (both ends included).
  int _rangeDays() => _rangeEnd().difference(_rangeStart()).inDays + 1;

  // The previous period: same number of days, right before the selected one.
  // "This Month" is compared with the previous month, for the same number
  // of days (so day 2 of this month is compared with days 1-2 of last month).
  DateTime _prevStart() {
    if (selectedRange == "This Month") {
      final now = DateTime.now();
      return DateTime(now.year, now.month - 1, 1);
    }
    return _prevEnd().subtract(Duration(days: _rangeDays() - 1));
  }

  DateTime _prevEnd() {
    if (selectedRange == "This Month") {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 1, 1);
      final lastDayOfPrevMonth = DateTime(now.year, now.month, 0);
      final end = start.add(Duration(days: _rangeDays() - 1));
      return end.isAfter(lastDayOfPrevMonth) ? lastDayOfPrevMonth : end;
    }
    return _rangeStart().subtract(const Duration(days: 1));
  }

  String _rangeLabel() {
    if (selectedRange == "Custom Range") return "Custom Range";
    return selectedRange;
  }

  // The 7-day chart always needs the last 7 days, and the comparison needs
  // the previous period, so the streams start from whichever is earliest.
  DateTime _streamStart() {
    final weekAgo = _today().subtract(const Duration(days: 6));
    final prev = _prevStart();
    return prev.isBefore(weekAgo) ? prev : weekAgo;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    return _service.watchEntriesSince(
      QueueAdminService.dayKeyOf(_streamStart()),
    );
  }

  // Payments of the same period (one range filter + orderBy on the same
  // field, so no composite index is needed).
  Stream<QuerySnapshot<Map<String, dynamic>>> _buildPaymentStream() {
    return FirebaseFirestore.instance
        .collection('payments')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_prevStart()),
        )
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _restartStreams() {
    _stream = _buildStream();
    _paymentStream = _buildPaymentStream();
  }

  Future<void> _onRangeChanged(String? value) async {
    if (value == null) return;

    if (value == "Custom Range") {
      await _pickCustomRange();
      return;
    }

    setState(() {
      selectedRange = value;
      _restartStreams();
    });
  }

  Future<void> _pickCustomRange() async {
    final today = _today();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
      initialDateRange: _customRange,
    );
    if (picked == null || !mounted) return;

    var start = _dateOnly(picked.start);
    final end = _dateOnly(picked.end);
    if (end.difference(start).inDays + 1 > _maxCustomDays) {
      start = end.subtract(const Duration(days: _maxCustomDays - 1));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A custom range can be at most 90 days.'),
        ),
      );
    }

    setState(() {
      selectedRange = "Custom Range";
      _customRange = DateTimeRange(start: start, end: end);
      _restartStreams();
    });
  }

  // Raw maps of the entries whose day is between [from] and [to] (inclusive).
  List<Map<String, dynamic>> _entriesBetween(
    QueueDocs all,
    DateTime from,
    DateTime to,
  ) {
    final fromKey = QueueAdminService.dayKeyOf(from);
    final toKey = QueueAdminService.dayKeyOf(to);
    return all
        .map((d) => d.data())
        .where((d) {
          final k = d['dayKey']?.toString() ?? '';
          return k.compareTo(fromKey) >= 0 && k.compareTo(toKey) <= 0;
        })
        .toList();
  }

  // Raw maps of the payments created between [from] and [to] (inclusive).
  List<Map<String, dynamic>> _paymentsBetween(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
    DateTime from,
    DateTime to,
  ) {
    final end = to.add(const Duration(days: 1));
    return all.map((d) => d.data()).where((d) {
      final t = d['createdAt'];
      if (t is! Timestamp) return false;
      final dt = t.toDate();
      return !dt.isBefore(from) && dt.isBefore(end);
    }).toList();
  }

  Future<void> _export(ReportData report, {required bool print}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      if (print) {
        await ReportPdf.printReport(
          report,
          hospital: _hospitalName,
          generatedBy: _adminName,
        );
      } else {
        await ReportPdf.download(
          report,
          hospital: _hospitalName,
          generatedBy: _adminName,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create the report. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const Positioned.fill(child: BgBoxes()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 700;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _paymentStream,
                      builder: (context, paymentSnapshot) {
                        // Everything the stream gave us (at least the last 7 days).
                        final QueueDocs allDocs = snapshot.data?.docs ?? [];

                        // Only the days inside the selected range.
                        final String startKey = QueueAdminService.dayKeyOf(
                          _rangeStart(),
                        );
                        final String endKey = QueueAdminService.dayKeyOf(
                          _rangeEnd(),
                        );
                        final QueueDocs docs = allDocs.where((d) {
                          final k = d.data()['dayKey']?.toString() ?? '';
                          return k.compareTo(startKey) >= 0 &&
                              k.compareTo(endKey) <= 0;
                        }).toList();
                        final int rangeDays = _rangeDays();

                        // One object for the cards, the comparison and the PDF.
                        final allPayments = paymentSnapshot.data?.docs ?? [];
                        final ReportData report = ReportBuilder.build(
                          entries: _entriesBetween(
                            allDocs,
                            _rangeStart(),
                            _rangeEnd(),
                          ),
                          prevEntries: _entriesBetween(
                            allDocs,
                            _prevStart(),
                            _prevEnd(),
                          ),
                          payments: _paymentsBetween(
                            allPayments,
                            _rangeStart(),
                            _rangeEnd(),
                          ),
                          prevPayments: _paymentsBetween(
                            allPayments,
                            _prevStart(),
                            _prevEnd(),
                          ),
                          from: _rangeStart(),
                          to: _rangeEnd(),
                          prevFrom: _prevStart(),
                          prevTo: _prevEnd(),
                          rangeLabel: _rangeLabel(),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMobile) ...[
                              Row(
                                children: [
                                  Text(
                                    "Reports & Analytics",
                                    style: AppTypography.title,
                                  ),
                                  const Spacer(),
                                  const LiveDateTimeWidget(),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Analyze queue performance, patient flow, waiting times, and operational efficiency.",
                                style: AppTypography.subtitle,
                              ),
                              const SizedBox(height: 24),
                            ] else
                              const SizedBox(height: 15),

                            // Date-range filter + report buttons
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _buildFilterDropdown(
                                  icon: Icons.calendar_today_outlined,
                                  value: selectedRange,
                                  items: _ranges,
                                  onChanged: _onRangeChanged,
                                ),
                                if (selectedRange == "Custom Range")
                                  TextButton.icon(
                                    onPressed: _pickCustomRange,
                                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                                    label: Text(
                                      '${ReportBuilder.fmtDate(_rangeStart())} - ${ReportBuilder.fmtDate(_rangeEnd())}',
                                    ),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: _exporting
                                      ? null
                                      : () => _export(report, print: false),
                                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                  label: const Text('Download PDF'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _exporting
                                      ? null
                                      : () => _export(report, print: true),
                                  icon: _exporting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.print_outlined, size: 18),
                                  label: const Text('Print Report'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryPurple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),

                            if (snapshot.hasError) ...[
                              const SizedBox(height: 12),
                              Text(
                                QueueAdminService.friendlyError(snapshot.error!),
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Summary numbers (live from Firestore)
                            _buildStatCardsSection(report, isMobile),
                            const SizedBox(height: 16),

                            // This period compared with the previous one
                            _buildComparisonCard(report),
                            const SizedBox(height: 28),

                        // Weekly patient flow chart (always the last 7 days)
                        RoundedCard(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [SevenDayPatientsChart(docs: allDocs)],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Peak hour + department distribution charts —
                        // desktop: side by side. Mobile: stacked full-width.
                        isMobile
                            ? Column(
                                children: [
                                  RoundedCard(
                                    color: Colors.white,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Peak Hour Patient Count",
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        PeakHourChart(docs: docs),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  RoundedCard(
                                    color: Colors.white,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Patients by Department",
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        PatientsByDepartmentChart(docs: docs),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: RoundedCard(
                                      color: Colors.white,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Peak Hour Patient Count",
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          PeakHourChart(docs: docs),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: RoundedCard(
                                      color: Colors.white,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Patients by Department",
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          PatientsByDepartmentChart(docs: docs),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        const SizedBox(height: 20),

                        // Completed vs cancelled comparison chart
                        RoundedCard(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Completed vs Cancelled Queues",
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              CompletedVsCancelledChart(docs: docs),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Doctor workload breakdown chart
                        RoundedCard(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Doctor Workload",
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              DoctorWorkloadChart(docs: docs, days: rangeDays),
                            ],
                          ),
                        ),

                        const SizedBox(height: 80),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // "Rs. 17.5k" for thousands, "Rs. 950" below that.
  String _moneyShort(num v) {
    final n = v.abs();
    final sign = v < 0 ? '-' : '';
    if (n >= 1000000) {
      return '${sign}Rs. ${_trim(n / 1000000)}M';
    }
    if (n >= 1000) {
      return '${sign}Rs. ${_trim(n / 1000)}k';
    }
    return '${sign}Rs. ${n.round()}';
  }

  String _trim(double v) {
    final t = v.toStringAsFixed(1);
    return t.endsWith('.0') ? t.substring(0, t.length - 2) : t;
  }

  // 95 -> "1h 35m", 40 -> "40 min"
  String _dur(int? minutes) {
    if (minutes == null) return "--";
    if (minutes < 60) return "$minutes min";
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? "${h}h" : "${h}h ${m}m";
  }

  // "27 Oct" (no year) for short date labels.
  String _short(DateTime d) =>
      ReportBuilder.fmtDate(d).replaceFirst(RegExp(r' \d{4}$'), '');

  String _shortRange(DateTime a, DateTime b) =>
      a == b ? _short(a) : '${_short(a)} - ${_short(b)}';

  // ONE card: 4 main numbers in a row, and the 3 smaller ones as a line below.
  Widget _buildStatCardsSection(ReportData r, bool isMobile) {
    Widget kpi(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      );
    }

    Widget small(String label, String value, Color dot) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label  ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    final items = [
      kpi("Total Tokens", "${r.total}"),
      kpi("Completed", "${r.completed}"),
      kpi("Avg Waiting", _dur(r.avgWaitMin)),
      kpi("Net Revenue", _moneyShort(r.net)),
    ];

    Widget top;
    if (isMobile) {
      top = Wrap(
        spacing: 24,
        runSpacing: 18,
        children: [for (final i in items) SizedBox(width: 140, child: i)],
      );
    } else {
      top = IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: Colors.grey.shade200,
                ),
              Expanded(child: items[i]),
            ],
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: RoundedCard(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            top,
            const SizedBox(height: 18),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 14),
            Wrap(
              spacing: 28,
              runSpacing: 10,
              children: [
                small("Cancelled", "${r.cancelled}", const Color(0xFFC62828)),
                small("Expired", "${r.expired}", const Color(0xFF9CA3AF)),
                small(
                  "Completion rate",
                  "${r.completionPercent}%",
                  AppColors.primaryPurple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // "This period vs previous period": a clear full-width table.
  Widget _buildComparisonCard(ReportData r) {
    String fmtChange(double? c) {
      if (c == null) return "--";
      final v = c.abs().toStringAsFixed(1);
      if (c > 0) return "+$v%";
      if (c < 0) return "\u2212$v%";
      return "0.0%";
    }

    Widget header(String t, {String? sub, bool right = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            crossAxisAlignment:
                right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                t,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              if (sub != null)
                Text(
                  sub,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
        );

    TableRow rowFor(
      String label,
      num cur,
      num prev,
      String curText,
      String prevText, {
      bool higherIsBetter = true,
    }) {
      double? change;
      if (prev != 0) change = ((cur - prev) / prev) * 100;
      Color color = Colors.grey.shade600;
      if (change != null && change != 0) {
        final good = higherIsBetter ? change > 0 : change < 0;
        color = good ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
      }

      Widget cell(String t, {bool right = true, Color? c, bool bold = false}) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Text(
            t,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: c ?? Colors.black87,
            ),
          ),
        );
      }

      return TableRow(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        children: [
          cell(label, right: false),
          cell(curText, bold: true),
          cell(prevText, c: Colors.grey.shade700),
          cell(fmtChange(change), c: color, bold: true),
        ],
      );
    }

    final nothingBefore = r.prevTotal == 0 && r.prevNet == 0;

    return SizedBox(
      width: double.infinity,
      child: RoundedCard(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Compared with previous period",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2.2),
                1: FlexColumnWidth(1.4),
                2: FlexColumnWidth(1.4),
                3: FlexColumnWidth(1.1),
              },
              children: [
                TableRow(
                  children: [
                    header("Metric"),
                    header("Current", sub: _shortRange(r.from, r.to), right: true),
                    header(
                      "Previous",
                      sub: _shortRange(r.prevFrom, r.prevTo),
                      right: true,
                    ),
                    header("Change", right: true),
                  ],
                ),
                rowFor("Patients served", r.completed, r.prevCompleted,
                    "${r.completed}", "${r.prevCompleted}"),
                rowFor("Total tokens", r.total, r.prevTotal,
                    "${r.total}", "${r.prevTotal}"),
                rowFor("Net revenue", r.net, r.prevNet,
                    _moneyShort(r.net), _moneyShort(r.prevNet)),
                rowFor(
                  "Avg. waiting",
                  r.avgWaitMin == null ? 0 : (r.prevAvgWaitMin ?? 0),
                  r.prevAvgWaitMin ?? 0,
                  _dur(r.avgWaitMin),
                  _dur(r.prevAvgWaitMin),
                  higherIsBetter: false, // a lower waiting time is better
                ),
              ],
            ),
            if (nothingBefore) ...[
              const SizedBox(height: 10),
              Text(
                "No tokens or payments in the previous period, so there is nothing to compare with yet.",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Builds a bordered dropdown with a leading icon, used for the
  // date-range filter above the stat cards.
  Widget _buildFilterDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}