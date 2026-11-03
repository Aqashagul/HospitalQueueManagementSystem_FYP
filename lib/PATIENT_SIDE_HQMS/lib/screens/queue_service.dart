import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/doctor.dart';



/// Result of joining a queue, used by the success and tracking screens.
class JoinedQueueResult {
  final String entryId; // Firestore document id of the queue entry
  final String token; // e.g. "A-001"
  final int seq; // 1, 2, 3... order of joining for this doctor that day
  final int patientsAhead; // active patients ahead of this one right now
  final String doctorName;
  final String department;

  const JoinedQueueResult({
    required this.entryId,
    required this.token,
    required this.seq,
    required this.patientsAhead,
    required this.doctorName,
    required this.department,
  });
}

class QueueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// A token stays valid this many hours after the patient took it.
  /// Keep this the same as QueueAdminService.validHours in the admin app.
  static const int validHours = 24;

  /// Day key like "20261014". Token numbers restart every day.
  static String dayKeyOf(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// True for statuses that still occupy a place in the queue.
  static bool isActiveStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'waiting':
      case 'in consultation':
      case 'in-progress':
      case 'in progress':
        return true;
      default:
        return false;
    }
  }

  /// True when the token was closed because it was never finished.
  static bool isExpiredStatus(String? raw) =>
      (raw ?? '').toLowerCase() == 'expired';

  /// True when the token was taken more than [validHours] hours ago.
  /// joinedAt is null for a moment right after joining: not old then.
  static bool isStale(Map<String, dynamic>? data) {
    final t = data?['joinedAt'];
    if (t is! Timestamp) return false;
    return DateTime.now().difference(t.toDate()) >
        const Duration(hours: validHours);
  }

  /// Day keys that can hold entries still valid right now
  /// (today and the days back to "now minus validHours").
  static List<String> windowDayKeys() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: validHours));
    final today = DateTime(now.year, now.month, now.day);
    var day = DateTime(start.year, start.month, start.day);
    final keys = <String>[];
    while (!day.isAfter(today)) {
      keys.add(dayKeyOf(day));
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return keys;
  }

  /// Does this entry count for the live queue right now? Everything from
  /// today does; an earlier day only while the patient is still waiting /
  /// in consultation and the token is not older than [validHours].
  static bool inWindow(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final status = data['status']?.toString();
    if (isExpiredStatus(status)) return false;
    if (data['dayKey'] == dayKeyOf(DateTime.now())) return true;
    return isActiveStatus(status) && !isStale(data);
  }

  /// True when entry [a] is ahead of entry [b] in the line
  /// (older day first, then seq, because seq restarts every day).
  static bool isBefore(Map<String, dynamic> a, Map<String, dynamic> b) {
    final dayA = a['dayKey']?.toString() ?? '';
    final dayB = b['dayKey']?.toString() ?? '';
    if (dayA != dayB) return dayA.compareTo(dayB) < 0;
    final seqA = a['seq'];
    final seqB = b['seq'];
    return seqA is int && seqB is int && seqA < seqB;
  }

  /// Message shown when the patient already holds an active token.
  static String _alreadyActiveMessage(Map<String, dynamic> entry) {
    final token = entry['token']?.toString() ?? '';
    final doctor = entry['doctorName']?.toString() ?? 'a doctor';
    return 'You already have an active token'
        '${token.isEmpty ? '' : ' ($token)'} with $doctor. '
        'Please wait until it is completed before taking another token.';
  }

  /// All of today's queue entries for one doctor (live).
  /// Two equality filters only, so no composite index is needed.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTodaysEntries(
    String doctorId,
  ) {
    return _db
        .collection('queue_entries')
        .where('doctorId', isEqualTo: doctorId)
        .where('dayKey', isEqualTo: dayKeyOf(DateTime.now()))
        .snapshots();
  }

  /// Today's entries plus the earlier-day patients whose token is still
  /// valid, for one doctor (live). Filter the result with [inWindow].
  /// An equality filter and an "in" filter need no composite index.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveEntries(
    String doctorId,
  ) {
    return _db
        .collection('queue_entries')
        .where('doctorId', isEqualTo: doctorId)
        .where('dayKey', whereIn: windowDayKeys())
        .snapshots();
  }

  /// Removes the patient's entry from the queue.
  Future<void> leaveQueue(String entryId) {
    return _db.collection('queue_entries').doc(entryId).delete();
  }

  /// Creates a queue entry for the logged-in patient with the given doctor.
  ///
  /// One active token at a time: while the patient has a token that is
  /// still Waiting / In Consultation (and not older than [validHours]) with
  /// ANY doctor, they cannot take a token with another doctor (or the same
  /// one again). Once the entry is completed, cancelled, expired, or the
  /// patient leaves the queue, they can join again.
  ///
  /// The rule is enforced twice:
  ///  1. A quick query before the transaction (friendly message, and it also
  ///     covers entries created before the lock document existed).
  ///  2. Inside the transaction, through a small per-patient lock document
  ///     (patient_locks/{uid}) that points to the patient's latest entry.
  ///     This stays correct even if the join button is tapped twice quickly
  ///     on two different doctors.
  ///
  /// The entry document id is fixed per (doctor, day, patient), and the token
  /// number and the entry are written in ONE transaction, so two patients can
  /// never get the same token for the same doctor on the same day. The
  /// counter restarts every day (one counter per doctor per day).
  ///
  /// The doctor must also be "Available" at the moment of joining. This is
  /// checked on the server's copy of the doctor inside the transaction, so a
  /// patient on a stale screen cannot join an unavailable (or deleted) doctor.
  ///
  /// A token is only created for a confirmed payment: [paymentId] is the
  /// payments/{id} document that the admin marked 'Paid' (cash) or 'Accepted'
  /// (emergency). It is marked 'Used' in the same transaction, so one payment
  /// can never give two tokens.
  ///
  /// Throws a [StateError] (with a readable message) if nobody is logged in,
  /// the doctor is unavailable, the payment is not confirmed, or the patient
  /// already has an active token.
  Future<JoinedQueueResult> joinQueue(Doctor doctor, String paymentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to join a queue.');
    }

    final dayKey = dayKeyOf(DateTime.now());

    // 1) Pre-check: any still-valid active entry with ANY doctor?
    final mine = await _db
        .collection('queue_entries')
        .where('patientId', isEqualTo: user.uid)
        .where('dayKey', whereIn: windowDayKeys())
        .get();
    for (final d in mine.docs) {
      final data = d.data();
      if (isActiveStatus(data['status']?.toString()) && !isStale(data)) {
        throw StateError(_alreadyActiveMessage(data));
      }
    }

    // 1b) Token numbers still held by a valid patient from an EARLIER day
    //     (for example a late-night token from yesterday). Today's counter
    //     skips these, so two active patients never hold the same token.
    final doctorLine = await _db
        .collection('queue_entries')
        .where('doctorId', isEqualTo: doctor.id)
        .where('dayKey', whereIn: windowDayKeys())
        .get();
    final Set<int> busyNumbers = {};
    for (final d in doctorLine.docs) {
      final data = d.data();
      if (data['dayKey'] != dayKey &&
          inWindow(d) &&
          isActiveStatus(data['status']?.toString()) &&
          data['seq'] is int) {
        busyNumbers.add(data['seq'] as int);
      }
    }

    final doctorRef = _db.collection('doctors').doc(doctor.id);
    final counterRef =
        _db.collection('queue_counters').doc('${doctor.id}_$dayKey');
    // Fixed id: one possible entry per patient + doctor + day.
    final entryRef = _db
        .collection('queue_entries')
        .doc('${doctor.id}_${dayKey}_${user.uid}');
    // One lock document per patient: points at their latest entry.
    final lockRef = _db.collection('patient_locks').doc(user.uid);
    // The confirmed payment (or accepted emergency request) for this visit.
    final paymentRef = _db.collection('payments').doc(paymentId);

    final created = await _db.runTransaction<Map<String, dynamic>>((tx) async {
      // All reads first.

      // The doctor must still exist and be available right now.
      final doctorSnap = await tx.get(doctorRef);
      if (!doctorSnap.exists) {
        throw StateError('This doctor is no longer available.');
      }
      final doctorStatus =
          (doctorSnap.data()?['status'] as String? ?? 'Available')
              .toLowerCase();
      if (doctorStatus != 'available') {
        throw StateError(
          '${doctor.name} is currently unavailable. Please try again later.',
        );
      }

      final entrySnap = await tx.get(entryRef);
      if (entrySnap.exists &&
          isActiveStatus(entrySnap.data()?['status']?.toString())) {
        throw StateError("You are already in this doctor's queue.");
      }

      // Does the patient's latest entry (any doctor) still hold a place?
      final lockSnap = await tx.get(lockRef);
      final lockedId = lockSnap.data()?['entryId'] as String?;
      if (lockedId != null && lockedId != entryRef.id) {
        final lockedEntrySnap =
            await tx.get(_db.collection('queue_entries').doc(lockedId));
        final lockedData = lockedEntrySnap.data();
        if (lockedEntrySnap.exists &&
            lockedData != null &&
            isActiveStatus(lockedData['status']?.toString()) &&
            !isStale(lockedData)) {
          throw StateError(_alreadyActiveMessage(lockedData));
        }
      }

      // The payment must belong to this patient and this doctor, and must be
      // confirmed by the admin.
      final paymentSnap = await tx.get(paymentRef);
      final payment = paymentSnap.data();
      if (payment == null ||
          payment['patientId'] != user.uid ||
          payment['doctorId'] != doctor.id) {
        throw StateError('This payment does not belong to this visit.');
      }
      final paymentStatus = payment['status']?.toString();
      if (paymentStatus != 'Paid' && paymentStatus != 'Accepted') {
        throw StateError('Your payment has not been confirmed yet.');
      }

      final counterSnap = await tx.get(counterRef);
      final last = counterSnap.exists
          ? (counterSnap.data()?['last'] as int? ?? 0)
          : 0;
      var next = last + 1;
      // Skip numbers still held by an active patient from an earlier day.
      while (busyNumbers.contains(next)) {
        next++;
      }
      final token = '${doctor.tokenPrefix}-${next.toString().padLeft(3, '0')}';

      // Then writes.
      tx.set(counterRef, {'last': next});
      tx.set(entryRef, {
        'token': token,
        'seq': next,
        'dayKey': dayKey,
        'patientId': user.uid,
        'patientName': user.displayName ?? '',
        'phone': user.phoneNumber ?? '',
        'doctorId': doctor.id,
        'doctorName': doctor.name,
        'department': doctor.departmentName,
        'status': 'Waiting',
        'paymentId': paymentId,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      tx.set(lockRef, {'entryId': entryRef.id, 'dayKey': dayKey});
      // The payment is used up by this token.
      tx.update(paymentRef, {
        'status': 'Used',
        'entryId': entryRef.id,
        'token': token,
        'usedAt': FieldValue.serverTimestamp(),
      });

      return {'token': token, 'seq': next};
    });

    final int seq = created['seq'] as int;

    // How many active patients are ahead of this one right now
    // (including late-night patients from the day before).
    final line = await _db
        .collection('queue_entries')
        .where('doctorId', isEqualTo: doctor.id)
        .where('dayKey', whereIn: windowDayKeys())
        .get();
    final me = {'dayKey': dayKey, 'seq': seq};
    final int ahead = line.docs.where((d) {
      return inWindow(d) &&
          isActiveStatus(d.data()['status']?.toString()) &&
          isBefore(d.data(), me);
    }).length;

    return JoinedQueueResult(
      entryId: entryRef.id,
      token: created['token'] as String,
      seq: seq,
      patientsAhead: ahead,
      doctorName: doctor.name,
      department: doctor.departmentName,
    );
  }
}