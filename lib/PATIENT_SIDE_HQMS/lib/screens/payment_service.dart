

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/models/doctor.dart';
import 'package:queue_management_system/PATIENT_SIDE_HQMS/lib/screens/queue_service.dart';

/// A patient's payment requests (collection: payments).
///
/// Flow:
///  1. [startRequest]: the patient taps "Join Queue". A request is created
///     (status Pending). A normal doctor needs a cash payment at the
///     reception; a doctor with fee 0, or an "emergency" request, needs the
///     admin to accept it.
///  2. The admin marks it Paid (or Accepted for an emergency).
///  3. [issueToken]: the token is created from the confirmed payment, and the
///     payment becomes Used.
///
/// The patient can never mark a payment as Paid themselves (Firestore rules).
class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// A pending request is valid this many minutes.
  /// Keep this the same as PaymentAdminService.requestValidMinutes in the admin app.
  static const int requestValidMinutes = 30;

  /// True when a Pending request is older than [requestValidMinutes].
  static bool isStale(Map<String, dynamic> d) {
    final t = d['createdAt'];
    if (t is! Timestamp) return false; // just created, server time not set yet
    return DateTime.now().difference(t.toDate()) >
        const Duration(minutes: requestValidMinutes);
  }

  /// The status to show: an old Pending request counts as Expired.
  static String effectiveStatus(Map<String, dynamic>? d) {
    final s = d?['status']?.toString() ?? '';
    if (s == 'Pending' && isStale(d!)) return 'Expired';
    return s;
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

  /// Starts a payment request with this doctor and returns its id.
  /// If the patient already has an open request with the SAME doctor, that
  /// one is returned, so reopening the screen never creates a second one.
  ///
  /// Throws a [StateError] (with a readable message) if nobody is logged in,
  /// the doctor is unavailable, or the patient already has an active token or
  /// an open request with another doctor.
  Future<String> startRequest(Doctor doctor, {bool emergency = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to join a queue.');
    }

    // 1) One active token at a time.
    final entries = await _db
        .collection('queue_entries')
        .where('patientId', isEqualTo: user.uid)
        .where('dayKey', whereIn: QueueService.windowDayKeys())
        .get();
    for (final d in entries.docs) {
      final data = d.data();
      if (QueueService.isActiveStatus(data['status']?.toString()) &&
          !QueueService.isStale(data)) {
        final token = data['token']?.toString() ?? '';
        final name = data['doctorName']?.toString() ?? 'a doctor';
        throw StateError(
          'You already have an active token'
          '${token.isEmpty ? '' : ' ($token)'} with $name. '
          'Please wait until it is completed before taking another token.',
        );
      }
    }

    // 2) Is there already an open request?
    final mine = await _db
        .collection('payments')
        .where('patientId', isEqualTo: user.uid)
        .get();
    for (final d in mine.docs) {
      final data = d.data();
      final status = effectiveStatus(data);
      final open =
          status == 'Pending' || status == 'Paid' || status == 'Accepted';
      if (!open) continue;
      if (data['doctorId'] == doctor.id) return d.id;
      final other = data['doctorName']?.toString() ?? 'another doctor';
      throw StateError(
        'You already have an open request with $other. '
        'Cancel it first to choose a different doctor.',
      );
    }

    // 3) The doctor must exist and be available. The fee is read from the
    //    server's copy of the doctor.
    final doctorSnap = await _db.collection('doctors').doc(doctor.id).get();
    final doctorData = doctorSnap.data();
    if (!doctorSnap.exists || doctorData == null) {
      throw StateError('This doctor is no longer available.');
    }
    final status = (doctorData['status']?.toString() ?? 'Available')
        .toLowerCase();
    if (status != 'available') {
      throw StateError(
        '${doctor.name} is currently unavailable. Please try again later.',
      );
    }
    final int fee = (doctorData['fee'] as num?)?.toInt() ?? 0;

    // A doctor with fee 0 (or an emergency) needs the admin to accept.
    final bool isEmergency = emergency || fee <= 0;

    // 4) The patient's name (the queue needs a real name).
    String name = user.displayName ?? '';
    if (name.isEmpty) {
      final profile = await _db.collection('users').doc(user.uid).get();
      name = profile.data()?['name']?.toString() ?? '';
    }
    if (name.isEmpty) {
      throw StateError('Please add your name to your profile first.');
    }

    final ref = await _db.collection('payments').add({
      'patientId': user.uid,
      'patientName': name,
      'phone': user.phoneNumber ?? '',
      'doctorId': doctor.id,
      'doctorName': doctor.name,
      'department': doctor.departmentName,
      'type': isEmergency ? 'emergency' : 'cash',
      'amount': isEmergency ? 0 : fee,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// One payment request (live).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPayment(String id) {
    return _db.collection('payments').doc(id).snapshots();
  }

  /// All payments of the logged-in patient (live). Newest first is done by
  /// the screen (one equality filter only, so no index is needed).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMine() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _db
        .collection('payments')
        .where('patientId', isEqualTo: uid)
        .snapshots();
  }

  /// The patient cancels their own pending request.
  Future<void> cancel(String paymentId) {
    return _db.collection('payments').doc(paymentId).update({
      'status': 'Cancelled',
    });
  }

  /// Creates the token from a confirmed payment (the payment becomes Used).
  Future<JoinedQueueResult> issueToken(Doctor doctor, String paymentId) {
    return QueueService().joinQueue(doctor, paymentId);
  }
}