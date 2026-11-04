// >>> ADMIN APP. New file, e.g. lib/services/payment_admin_service.dart
// Imports needed at the top:
//   import 'dart:async';
//   import 'package:cloud_firestore/cloud_firestore.dart';
//   import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Payment requests of patients (collection: payments).
///
/// Status of a payment document:
///   Pending   patient asked to pay at the reception / asked for an emergency visit
///   Paid      admin confirmed the cash (token not created yet)
///   Accepted  admin accepted an emergency request (token not created yet)
///   Used      the patient's token was created from it
///   Rejected  admin rejected an emergency request
///   Cancelled the patient cancelled the request
///   Expired   nobody confirmed the request in time (shown automatically)
///   Refunded  the cash was given back
class PaymentAdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// A pending request is valid this many minutes.
  /// Keep this the same as PaymentService.requestValidMinutes in the patient app.
  static const int requestValidMinutes = 30;

  /// The Payments page shows the last this many days (keeps reads low).
  static const int historyDays = 30;

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  static String dayKeyOf(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// True when a Pending request is older than [requestValidMinutes].
  static bool isStale(Map<String, dynamic> d) {
    final t = d['createdAt'];
    if (t is! Timestamp) return false; // just created, server time not set yet
    return DateTime.now().difference(t.toDate()) >
        const Duration(minutes: requestValidMinutes);
  }

  /// The status to show: an old Pending request counts as Expired.
  static String effectiveStatus(Map<String, dynamic> d) {
    final s = d['status']?.toString() ?? '';
    if (s == 'Pending' && isStale(d)) return 'Expired';
    return s;
  }

  /// Words the admin sees for a status.
  static String statusLabel(String s) {
    switch (s) {
      case 'Used':
        return 'Token issued';
      default:
        return s;
    }
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

  static String friendlyError(Object e) {
    if (e is StateError) return e.message;
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return "You don't have permission to do this.";
        case 'unavailable':
        case 'network-request-failed':
        case 'deadline-exceeded':
          return 'Network problem. Please check your internet and try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  // ---------------------------------------------------------------------
  // Live data
  // ---------------------------------------------------------------------

  /// Payments of the last [historyDays] days, newest first (live).
  /// One range filter and one orderBy on the same field: no composite index.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecent() {
    final since = DateTime.now().subtract(const Duration(days: historyDays));
    return _db
        .collection('payments')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// How many requests wait for the admin right now (for a sidebar badge).
  Stream<int> watchPendingCount() {
    return _db
        .collection('payments')
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .map((s) => s.docs.where((d) => !isStale(d.data())).length);
  }

  // ---------------------------------------------------------------------
  // Actions (all need admin rights)
  // ---------------------------------------------------------------------

  String? get _adminId => FirebaseAuth.instance.currentUser?.uid;

  /// Cash received: Pending -> Paid, with a receipt number like R-20261101-003.
  Future<void> markPaid(String paymentId) async {
    final ref = _db.collection('payments').doc(paymentId);
    final counterRef =
        _db.collection('receipt_counters').doc(dayKeyOf(DateTime.now()));
    final dayKey = dayKeyOf(DateTime.now());

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) {
        throw StateError('This payment request no longer exists.');
      }
      if (data['status'] != 'Pending') {
        throw StateError('This request was already handled.');
      }
      if (isStale(data)) {
        throw StateError(
          'This request has expired. Ask the patient to send a new request.',
        );
      }
      if (data['type'] != 'cash') {
        throw StateError('An emergency request is accepted, not paid.');
      }

      final counterSnap = await tx.get(counterRef);
      final last = (counterSnap.data()?['last'] as num?)?.toInt() ?? 0;
      final next = last + 1;

      tx.set(counterRef, {'last': next});
      tx.update(ref, {
        'status': 'Paid',
        'paidAt': FieldValue.serverTimestamp(),
        'receivedBy': _adminId,
        'receiptNo': 'R-$dayKey-${next.toString().padLeft(3, '0')}',
      });
    });
  }

  /// Emergency request accepted: Pending -> Accepted. The patient's token is
  /// created right after.
  Future<void> acceptEmergency(String paymentId) async {
    final ref = _db.collection('payments').doc(paymentId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) {
        throw StateError('This request no longer exists.');
      }
      if (data['status'] != 'Pending') {
        throw StateError('This request was already handled.');
      }
      if (isStale(data)) {
        throw StateError(
          'This request has expired. Ask the patient to send a new request.',
        );
      }
      tx.update(ref, {
        'status': 'Accepted',
        'decidedAt': FieldValue.serverTimestamp(),
        'decidedBy': _adminId,
      });
    });
  }

  /// Request rejected: Pending -> Rejected.
  Future<void> reject(String paymentId) async {
    final ref = _db.collection('payments').doc(paymentId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) {
        throw StateError('This request no longer exists.');
      }
      if (data['status'] != 'Pending') {
        throw StateError('This request was already handled.');
      }
      tx.update(ref, {
        'status': 'Rejected',
        'decidedAt': FieldValue.serverTimestamp(),
        'decidedBy': _adminId,
      });
    });
  }

  /// Cash given back to the patient: Paid / Used -> Refunded.
  Future<void> refund(String paymentId) async {
    final ref = _db.collection('payments').doc(paymentId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) {
        throw StateError('This payment no longer exists.');
      }
      final s = data['status'];
      if (s != 'Paid' && s != 'Used') {
        throw StateError('Only a paid payment can be refunded.');
      }
      tx.update(ref, {
        'status': 'Refunded',
        'refundedAt': FieldValue.serverTimestamp(),
        'refundedBy': _adminId,
      });
    });
  }

  /// Closes Pending requests older than [requestValidMinutes] ("Expired").
  /// Reads only the Pending ones. Returns how many it closed.
  Future<int> expireStale() async {
    final snap = await _db
        .collection('payments')
        .where('status', isEqualTo: 'Pending')
        .get(const GetOptions(source: Source.server));

    final stale = snap.docs.where((d) => isStale(d.data())).toList();
    if (stale.isEmpty) return 0;

    final batch = _db.batch();
    for (final d in stale.take(400)) {
      batch.update(d.reference, {
        'status': 'Expired',
        'expiredAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return stale.length > 400 ? 400 : stale.length;
  }
}