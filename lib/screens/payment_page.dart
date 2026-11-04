
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/core/app_color.dart';
import 'package:queue_management_system/core/app_typography.dart';
import 'package:queue_management_system/screens/payment_admin_service.dart';
import 'package:queue_management_system/widgets/confirm_action_dialog.dart';
import 'package:queue_management_system/widgets/generic_p.dart/data_table_card.dart';
import 'package:queue_management_system/widgets/generic_p.dart/shared_widgets.dart';
import 'package:queue_management_system/widgets/resuable/bg_boxes.dart';
import 'package:queue_management_system/widgets/resuable/dashboard_searchbar.dart';
import 'package:queue_management_system/widgets/resuable/live_date_time_widget.dart';

class _PaymentRow {
  final String id;
  final Map<String, dynamic> data;

  const _PaymentRow(this.id, this.data);

  String get status => PaymentAdminService.effectiveStatus(data);
  bool get isEmergency => data['type'] == 'emergency';
  int get amount => (data['amount'] as num?)?.toInt() ?? 0;

  String _text(String key) {
    final v = data[key]?.toString() ?? '';
    return v.isEmpty ? '-' : v;
  }

  String get patient => _text('patientName');
  String get phone => _text('phone');
  String get doctor => _text('doctorName');
  String get department => _text('department');
  String get token => _text('token');
  String get receiptNo => _text('receiptNo');

  DateTime? _time(String key) {
    final v = data[key];
    return v is Timestamp ? v.toDate() : null;
  }

  DateTime? get createdAt => _time('createdAt');
  DateTime? get paidAt => _time('paidAt');
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final PaymentAdminService _service = PaymentAdminService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  Timer? _ticker;

  String _statusFilter = 'Status';
  String _search = '';

  // The payment whose action is running (blocks double taps).
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _stream = _service.watchRecent();
    // Old pending requests are closed ("Expired"). Fails quietly offline.
    _service.expireStale().catchError((_) => 0);
    // Keeps "5 min ago" and the expiry of pending requests fresh.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Messages and actions
  // -------------------------------------------------------------------------

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red.shade700 : const Color(0xFF2E7D32),
        ),
      );
  }

  Future<void> _run(
    String id,
    Future<void> Function() action,
    String doneMessage,
  ) async {
    if (_busyId != null) return;
    setState(() => _busyId = id);
    try {
      await action();
      _snack(doneMessage);
    } catch (e) {
      _snack(PaymentAdminService.friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmPaid(_PaymentRow row) async {
    final ok = await showConfirmActionDialog(
      context,
      icon: Icons.payments_outlined,
      color: const Color(0xFF2E7D32),
      title: 'Confirm Payment',
      message:
          'Have you received ${PaymentAdminService.money(row.amount)} in cash '
          'from this patient? Their token will be created right away.',
      confirmLabel: 'Mark as Paid',
      patientName: row.patient,
    );
    if (!ok || !mounted) return;
    await _run(
      row.id,
      () => _service.markPaid(row.id),
      'Payment confirmed for ${row.patient}',
    );
  }

  Future<void> _confirmAccept(_PaymentRow row) async {
    final ok = await showConfirmActionDialog(
      context,
      icon: Icons.emergency_outlined,
      color: const Color(0xFFE53935),
      title: 'Accept Emergency Request',
      message:
          'This patient will get a token right away and can see the doctor '
          'without paying a fee.',
      confirmLabel: 'Accept',
      patientName: row.patient,
    );
    if (!ok || !mounted) return;
    await _run(
      row.id,
      () => _service.acceptEmergency(row.id),
      'Emergency request accepted for ${row.patient}',
    );
  }

  Future<void> _confirmReject(_PaymentRow row) async {
    final ok = await showConfirmActionDialog(
      context,
      icon: Icons.block_rounded,
      color: const Color(0xFFE53935),
      title: 'Reject Request',
      message: 'This patient will be told that the request was not accepted.',
      confirmLabel: 'Reject',
      patientName: row.patient,
    );
    if (!ok || !mounted) return;
    await _run(
      row.id,
      () => _service.reject(row.id),
      'Request rejected',
    );
  }

  Future<void> _confirmRefund(_PaymentRow row) async {
    final ok = await showConfirmActionDialog(
      context,
      icon: Icons.undo_rounded,
      color: Colors.orange.shade700,
      title: 'Refund Payment',
      message:
          'Give ${PaymentAdminService.money(row.amount)} back to this patient '
          'in cash? This cannot be undone.',
      confirmLabel: 'Refund',
      patientName: row.patient,
    );
    if (!ok || !mounted) return;
    await _run(
      row.id,
      () => _service.refund(row.id),
      'Payment refunded to ${row.patient}',
    );
  }

  // -------------------------------------------------------------------------
  // Small helpers
  // -------------------------------------------------------------------------

  String _ago(DateTime? time) {
    if (time == null) return 'just now';
    final d = DateTime.now().difference(time);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  String _dateTime(DateTime? t) {
    if (t == null) return '-';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '${t.day} ${months[t.month - 1]}, $hour:$minute $period';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Paid':
      case 'Used':
      case 'Accepted':
        return const Color(0xFF2E7D32);
      case 'Pending':
        return const Color(0xFFB8860B);
      case 'Refunded':
        return const Color(0xFF3B82C4);
      default: // Rejected, Expired, Cancelled
        return Colors.grey.shade600;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        PaymentAdminService.statusLabel(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _emergencyChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5E3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'EMERGENCY',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFFE53935),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          const Positioned.fill(child: BgBoxes()),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      PaymentAdminService.friendlyError(snapshot.error!),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryPurple,
                  ),
                );
              }

              final all = snapshot.data!.docs
                  .map((d) => _PaymentRow(d.id, d.data()))
                  .toList();

              // ---- numbers for the cards ----
              final now = DateTime.now();
              bool collected(_PaymentRow r) =>
                  r.status == 'Paid' || r.status == 'Used';

              final int revenue = all
                  .where(collected)
                  .fold<int>(0, (sum, r) => sum + r.amount);
              final int todayCollection = all
                  .where((r) {
                    final t = r.paidAt;
                    return collected(r) &&
                        t != null &&
                        t.year == now.year &&
                        t.month == now.month &&
                        t.day == now.day;
                  })
                  .fold<int>(0, (sum, r) => sum + r.amount);
              final int paidCount = all.where(collected).length;

              final pending = all.where((r) => r.status == 'Pending').toList()
                ..sort((a, b) {
                  final ta = a.createdAt ?? now;
                  final tb = b.createdAt ?? now;
                  return ta.compareTo(tb); // oldest first
                });

              // ---- history table: filter + search ----
              final q = _search.trim().toLowerCase();
              final history = all.where((r) {
                final matchesStatus =
                    _statusFilter == 'Status' ||
                    PaymentAdminService.statusLabel(r.status) == _statusFilter;
                final matchesSearch =
                    q.isEmpty ||
                    r.patient.toLowerCase().contains(q) ||
                    r.phone.toLowerCase().contains(q) ||
                    r.token.toLowerCase().contains(q) ||
                    r.doctor.toLowerCase().contains(q) ||
                    r.receiptNo.toLowerCase().contains(q);
                return matchesStatus && matchesSearch;
              }).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isMobile = constraints.maxWidth < 700;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMobile) ...[
                          Row(
                            children: [
                              Text('Payments', style: AppTypography.title),
                              const Spacer(),
                              const LiveDateTimeWidget(),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Confirm cash payments and emergency requests. '
                            'A patient gets a token only after you confirm.',
                            style: AppTypography.subtitle,
                          ),
                          const SizedBox(height: 24),
                        ] else
                          const SizedBox(height: 15),

                        _buildStatCards(
                          isMobile: isMobile,
                          revenue: revenue,
                          paidCount: paidCount,
                          pendingCount: pending.length,
                          todayCollection: todayCollection,
                        ),
                        const SizedBox(height: 28),

                        _buildPendingSection(pending, isMobile: isMobile),
                        const SizedBox(height: 28),

                        Text(
                          'Payment History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last ${PaymentAdminService.historyDays} days',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildToolbar(isMobile: isMobile),
                        const SizedBox(height: 16),
                        _buildHistoryTable(history, isMobile: isMobile),
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 4 summary cards
  Widget _buildStatCards({
    required bool isMobile,
    required int revenue,
    required int paidCount,
    required int pendingCount,
    required int todayCollection,
  }) {
    final cardPadding =
        isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(18);
    final iconPadding = isMobile ? 8.0 : 12.0;
    final iconSize = isMobile ? 18.0 : 22.0;
    final valueSize = isMobile ? 16.0 : 22.0;

    final card1 = StatCard(
      icon: Icons.account_balance_wallet_outlined,
      iconColor: AppColors.primaryPurple,
      iconBgColor: const Color(0xFFE4D9F9),
      label: 'Total Revenue',
      value: PaymentAdminService.money(revenue),
      padding: cardPadding,
      iconContainerPadding: iconPadding,
      iconSize: iconSize,
      valueFontSize: valueSize,
    );
    final card2 = StatCard(
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF2E7D32),
      iconBgColor: const Color(0xFFD4EDDA),
      label: 'Paid Payments',
      value: '$paidCount',
      padding: cardPadding,
      iconContainerPadding: iconPadding,
      iconSize: iconSize,
      valueFontSize: valueSize,
    );
    final card3 = StatCard(
      icon: Icons.hourglass_empty,
      iconColor: const Color(0xFFB8860B),
      iconBgColor: const Color(0xFFFAF3D0),
      label: 'Pending Payments',
      value: '$pendingCount',
      padding: cardPadding,
      iconContainerPadding: iconPadding,
      iconSize: iconSize,
      valueFontSize: valueSize,
    );
    final card4 = StatCard(
      icon: Icons.today_outlined,
      iconColor: const Color(0xFF3B82C4),
      iconBgColor: const Color(0xFFD6EAF8),
      label: "Today's Collection",
      value: PaymentAdminService.money(todayCollection),
      padding: cardPadding,
      iconContainerPadding: iconPadding,
      iconSize: iconSize,
      valueFontSize: valueSize,
    );

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 8),
              Expanded(child: card2),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: card3),
              const SizedBox(width: 8),
              Expanded(child: card4),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: card1),
        const SizedBox(width: 16),
        Expanded(child: card2),
        const SizedBox(width: 16),
        Expanded(child: card3),
        const SizedBox(width: 16),
        Expanded(child: card4),
      ],
    );
  }

  // Requests that wait for the admin right now.
  Widget _buildPendingSection(
    List<_PaymentRow> pending, {
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pending Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(width: 10),
            if (pending.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${pending.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (pending.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  size: 34,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'No pending requests',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'New payment and emergency requests appear here live.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          ...pending.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPendingCard(r, isMobile: isMobile),
            ),
          ),
      ],
    );
  }

  Widget _buildPendingCard(_PaymentRow r, {required bool isMobile}) {
    final bool busy = _busyId == r.id;
    final bool anyBusy = _busyId != null;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                r.patient,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (r.isEmergency) ...[
              const SizedBox(width: 8),
              _emergencyChip(),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          r.phone,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        Text(
          '${r.doctor}  ·  ${r.department}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 2),
        Text(
          'Requested ${_ago(r.createdAt)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );

    final amount = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FEE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          r.isEmergency ? 'No fee' : PaymentAdminService.money(r.amount),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryPurple,
          ),
        ),
      ],
    );

    final actions = busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: r.isEmergency
                ? [
                    _actionButton(
                      'Accept',
                      const Color(0xFFE53935),
                      anyBusy ? null : () => _confirmAccept(r),
                    ),
                    _actionButton(
                      'Reject',
                      Colors.blueGrey.shade400,
                      anyBusy ? null : () => _confirmReject(r),
                    ),
                  ]
                : [
                    _actionButton(
                      'Mark as Paid',
                      const Color(0xFF2E7D32),
                      anyBusy ? null : () => _confirmPaid(r),
                    ),
                    _actionButton(
                      'Reject',
                      Colors.blueGrey.shade400,
                      anyBusy ? null : () => _confirmReject(r),
                    ),
                  ],
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: r.isEmergency
              ? const Color(0xFFFFC9C5)
              : Colors.grey.shade200,
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 12),
                amount,
                const SizedBox(height: 14),
                actions,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 4, child: info),
                Expanded(flex: 2, child: amount),
                actions,
              ],
            ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade200 : color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: onTap == null ? Colors.grey.shade400 : Colors.white,
          ),
        ),
      ),
    );
  }

  // Search + status filter for the history table.
  Widget _buildToolbar({required bool isMobile}) {
    final searchBar = DashboardSearchBar(
      hintText: 'Search patient, token, doctor or receipt...',
      onChanged: (query) => setState(() => _search = query),
    );

    final dropdown = _buildDropdown(
      value: _statusFilter,
      items: const [
        'Status',
        'Pending',
        'Paid',
        'Token issued',
        'Accepted',
        'Rejected',
        'Expired',
        'Cancelled',
        'Refunded',
      ],
      onChanged: (v) => setState(() => _statusFilter = v!),
      fillWidth: isMobile,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [searchBar, const SizedBox(height: 12), dropdown],
      );
    }
    return Row(
      children: [
        Expanded(child: searchBar),
        const SizedBox(width: 12),
        dropdown,
      ],
    );
  }

  Widget _buildHistoryTable(List<_PaymentRow> rows, {required bool isMobile}) {
    final table = DataTableCard<_PaymentRow>(
      items: rows,
      emptyMessage: 'No payments yet',
      columns: [
        TableColumn<_PaymentRow>(
          label: 'Receipt',
          flex: 3,
          cellBuilder: (r) => Text(
            r.receiptNo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryPurple,
            ),
          ),
        ),
        TableColumn<_PaymentRow>(
          label: 'Patient',
          flex: 3,
          cellBuilder: (r) => Row(
            children: [
              Flexible(
                child: Text(
                  r.patient,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (r.isEmergency) ...[
                const SizedBox(width: 6),
                _emergencyChip(),
              ],
            ],
          ),
        ),
        TableColumn<_PaymentRow>(
          label: 'Token',
          flex: 2,
          cellBuilder: (r) =>
              Text(r.token, style: const TextStyle(fontSize: 14)),
        ),
        TableColumn<_PaymentRow>(
          label: 'Doctor',
          flex: 3,
          cellBuilder: (r) => Text(
            r.doctor,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        TableColumn<_PaymentRow>(
          label: 'Fee',
          flex: 2,
          cellBuilder: (r) => Text(
            r.isEmergency ? 'No fee' : PaymentAdminService.money(r.amount),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        TableColumn<_PaymentRow>(
          label: 'Status',
          flex: 3,
          cellBuilder: (r) => Align(
            alignment: Alignment.centerLeft,
            child: _statusChip(r.status),
          ),
        ),
        TableColumn<_PaymentRow>(
          label: 'Time',
          flex: 3,
          cellBuilder: (r) => Text(
            _dateTime(r.paidAt ?? r.createdAt),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        TableColumn<_PaymentRow>(
          label: 'Action',
          flex: 2,
          cellBuilder: (r) {
            final canRefund =
                !r.isEmergency && (r.status == 'Paid' || r.status == 'Used');
            if (!canRefund) return const SizedBox.shrink();
            return GestureDetector(
              onTap: _busyId == null ? () => _confirmRefund(r) : null,
              child: Text(
                'Refund',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade800,
                ),
              ),
            );
          },
        ),
      ],
    );

    if (!isMobile) return table;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: 1100, child: table),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool fillWidth = false,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 196, 196, 196),
          width: 0.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: fillWidth,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: AppTypography.normaltext,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}