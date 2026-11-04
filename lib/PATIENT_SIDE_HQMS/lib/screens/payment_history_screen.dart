

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/payment_service.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/receipt_pdf.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/widgets/background_blobs.dart';
import 'package:queue_management_system/core/app_color.dart';


class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  static DateTime? _time(Map<String, dynamic> d, String key) {
    final v = d[key];
    return v is Timestamp ? v.toDate() : null;
  }

  static String _dateTime(DateTime? t) {
    if (t == null) return '-';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '${t.day} ${months[t.month - 1]} ${t.year}, $hour:$minute $period';
  }

  static String _statusLabel(String s) => s == 'Used' ? 'Paid' : s;

  static Color _statusColor(String s) {
    switch (s) {
      case 'Paid':
      case 'Used':
      case 'Accepted':
        return const Color(0xFF2E7D32);
      case 'Pending':
        return const Color(0xFFB8860B);
      case 'Refunded':
        return const Color(0xFF3B82C4);
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = PaymentService();

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: Stack(
        children: [
          const BackgroundBlobs(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 20, 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Payments & Receipts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: service.watchMine(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Could not load your payments. '
                              'Please check your internet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textGrey),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      // Newest first. Requests that never became a payment
                      // (cancelled / expired / rejected) are not receipts, so
                      // they are left out of this list.
                      final docs =
                          snapshot.data!.docs.where((d) {
                            final s = PaymentService.effectiveStatus(d.data());
                            return s == 'Paid' ||
                                s == 'Used' ||
                                s == 'Accepted' ||
                                s == 'Refunded' ||
                                s == 'Pending';
                          }).toList()..sort((a, b) {
                            final ta =
                                _time(a.data(), 'createdAt') ?? DateTime.now();
                            final tb =
                                _time(b.data(), 'createdAt') ?? DateTime.now();
                            return tb.compareTo(ta);
                          });

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No payments yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your receipts will appear here.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final data = docs[i].data();
                          final status = PaymentService.effectiveStatus(data);
                          final emergency = data['type'] == 'emergency';
                          final amount = (data['amount'] as num?)?.toInt() ?? 0;
                          final color = _statusColor(status);
                          final hasReceipt =
                              data['receiptNo'] != null &&
                              (status == 'Paid' ||
                                  status == 'Used' ||
                                  status == 'Refunded');

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: hasReceipt
                                ? () => _showReceipt(context, data)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.primary.withOpacity(.12)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color.withValues(alpha: .12),
                                    ),
                                    child: Icon(
                                      emergency
                                          ? Icons.emergency_outlined
                                          : Icons.receipt_long_outlined,
                                      size: 22,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['doctorName']?.toString() ?? '',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _dateTime(
                                            _time(data, 'paidAt') ??
                                                _time(data, 'createdAt'),
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textGrey,
                                          ),
                                        ),
                                        if (hasReceipt) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '${data['receiptNo']}  \u2022  Tap to view receipt',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        emergency
                                            ? 'No fee'
                                            : PaymentService.money(amount),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: .12),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // The receipt of one paid payment.
  static void _showReceipt(BuildContext context, Map<String, dynamic> data) {
    final status = PaymentService.effectiveStatus(data);
    final amount = (data['amount'] as num?)?.toInt() ?? 0;

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '-' : value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor(status).withValues(alpha: .12),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 30,
                    color: _statusColor(status),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Payment Receipt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['receiptNo']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                row('Date', _dateTime(_time(data, 'paidAt'))),
                row('Patient', data['patientName']?.toString() ?? ''),
                row('Doctor', data['doctorName']?.toString() ?? ''),
                row('Department', data['department']?.toString() ?? ''),
                row('Token', data['token']?.toString() ?? ''),
                row('Method', 'Cash at reception'),
                row('Status', _statusLabel(status)),
                const Divider(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(fontSize: 14, color: AppColors.textGrey),
                    ),
                    Text(
                      PaymentService.money(amount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await ReceiptPdf.download(data);
                      } catch (_) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Could not create the receipt. Please try again.'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text(
                      'Download PDF',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}