import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/doctor.dart';

/// Result of joining a queue, used by the success and tracking screens.
class JoinedQueueResult {
  final String entryId; // Firestore document id of the queue entry
  final String token; // e.g. "A-001"
  final int seq; // 1, 2, 3... order of joining for this doctor today
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

  /// Day key like "20261014". Queues restart every day.
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

  /// Removes the patient's entry from the queue.
  Future<void> leaveQueue(String entryId) {
    return _db.collection('queue_entries').doc(entryId).delete();
  }

  /// Creates a queue entry for the logged-in patient with the given doctor.
  ///
  /// One active token at a time: while the patient has a token that is
  /// still Waiting / In Consultation with ANY doctor today, they cannot take
  /// a token with another doctor (or the same one again). Once the entry is
  /// completed, cancelled, or the patient leaves the queue, they can join
  /// again.
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
  /// Throws a [StateError] (with a readable message) if nobody is logged in,
  /// the doctor is unavailable, or the patient already has an active token.
  Future<JoinedQueueResult> joinQueue(Doctor doctor) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to join a queue.');
    }

    final dayKey = dayKeyOf(DateTime.now());

    // 1) Pre-check: any active entry today with ANY doctor?
    final mine = await _db
        .collection('queue_entries')
        .where('patientId', isEqualTo: user.uid)
        .where('dayKey', isEqualTo: dayKey)
        .get();
    for (final d in mine.docs) {
      final data = d.data();
      if (isActiveStatus(data['status']?.toString())) {
        throw StateError(_alreadyActiveMessage(data));
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
            lockedData['dayKey'] == dayKey &&
            isActiveStatus(lockedData['status']?.toString())) {
          throw StateError(_alreadyActiveMessage(lockedData));
        }
      }

      final counterSnap = await tx.get(counterRef);
      final last = counterSnap.exists
          ? (counterSnap.data()?['last'] as int? ?? 0)
          : 0;
      final next = last + 1;
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
        'joinedAt': FieldValue.serverTimestamp(),
      });
      tx.set(lockRef, {'entryId': entryRef.id, 'dayKey': dayKey});

      return {'token': token, 'seq': next};
    });

    final int seq = created['seq'] as int;

    // How many active patients are ahead of this one right now.
    final todays = await _db
        .collection('queue_entries')
        .where('doctorId', isEqualTo: doctor.id)
        .where('dayKey', isEqualTo: dayKey)
        .get();
    final int ahead = todays.docs.where((d) {
      final data = d.data();
      final s = data['seq'];
      return s is int && s < seq && isActiveStatus(data['status']?.toString());
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