import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class QueueAdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Who did the last action and when (saved on the queue entry).
  Map<String, dynamic> get _actor => {
        'lastActionBy': FirebaseAuth.instance.currentUser?.uid,
        'lastActionAt': FieldValue.serverTimestamp(),
      };

  /// Day key like "20261014". Same format the patient app writes.
  static String dayKeyOf(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// Maps the different spellings of a status to one of
  /// "Waiting", "In Consultation", "Completed" (anything else is returned as-is).
  static String normalizeStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'waiting':
        return 'Waiting';
      case 'in consultation':
      case 'in-progress':
      case 'in progress':
        return 'In Consultation';
      case 'completed':
      case 'done':
        return 'Completed';
      default:
        return raw ?? '';
    }
  }

  static int seqOf(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      (d.data()['seq'] as num?)?.toInt() ?? 0;

  /// Turns any error into a short message the admin can read.
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

  /// Every queue entry of today, for all doctors (live).
  /// One equality filter only, so no composite index is needed.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTodaysEntries() {
    return _db
        .collection('queue_entries')
        .where('dayKey', isEqualTo: dayKeyOf(DateTime.now()))
        .snapshots();
  }

  /// Every queue entry from [startDayKey] (inclusive, format "yyyyMMdd")
  /// up to today, for all doctors (live). Used by the Reports page.
  /// One range filter on a single field, so no composite index is needed.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchEntriesSince(
    String startDayKey,
  ) {
    return _db
        .collection('queue_entries')
        .where('dayKey', isGreaterThanOrEqualTo: startDayKey)
        .snapshots();
  }

  /// Today's queue entries of one doctor (live).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTodaysEntriesForDoctor(
    String doctorId,
  ) {
    return _db
        .collection('queue_entries')
        .where('doctorId', isEqualTo: doctorId)
        .where('dayKey', isEqualTo: dayKeyOf(DateTime.now()))
        .snapshots();
  }

  // One-time read from the SERVER (throws if offline instead of using a
  // stale cache), so actions never run on old data.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _todaysForDoctor(
    String doctorId,
  ) async {
    final snap = await _db
        .collection('queue_entries')
        .where('doctorId', isEqualTo: doctorId)
        .where('dayKey', isEqualTo: dayKeyOf(DateTime.now()))
        .get(const GetOptions(source: Source.server));
    return snap.docs;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _withStatus(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String status,
  ) {
    return docs
        .where((d) => normalizeStatus(d.data()['status']?.toString()) == status)
        .toList()
      ..sort((a, b) => seqOf(a).compareTo(seqOf(b)));
  }

  /// Calls the next waiting patient (lowest seq) of this doctor in.
  /// Fails if someone is already in consultation or nobody is waiting.
  Future<void> callNext(String doctorId) async {
    final docs = await _todaysForDoctor(doctorId);

    if (_withStatus(docs, 'In Consultation').isNotEmpty) {
      throw StateError('A patient is already in consultation.');
    }
    final waiting = _withStatus(docs, 'Waiting');
    if (waiting.isEmpty) {
      throw StateError('No patients are waiting.');
    }

    await _markInConsultation(waiting.first.reference);
  }

  /// Calls one specific waiting patient in (not necessarily the next one in
  /// line). Fails if someone is already in consultation or this patient is
  /// no longer waiting.
  Future<void> callSpecific(String doctorId, String entryId) async {
    final docs = await _todaysForDoctor(doctorId);

    if (_withStatus(docs, 'In Consultation').isNotEmpty) {
      throw StateError('A patient is already in consultation.');
    }

    final match = docs.where((d) => d.id == entryId).toList();
    if (match.isEmpty ||
        normalizeStatus(match.first.data()['status']?.toString()) !=
            'Waiting') {
      throw StateError('This patient is no longer waiting.');
    }

    await _markInConsultation(match.first.reference);
  }

  // Moves one waiting entry to "In Consultation" (checked again inside the
  // transaction, in case it changed a moment ago).
  Future<void> _markInConsultation(
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (normalizeStatus(snap.data()?['status']?.toString()) != 'Waiting') {
        throw StateError('That patient is no longer waiting. Please try again.');
      }
      tx.update(ref, {
        'status': 'In Consultation',
        'calledAt': FieldValue.serverTimestamp(),
        ..._actor,
      });
    });
  }

  /// Marks the doctor's current patient (In Consultation) as completed.
  Future<void> completeCurrent(String doctorId) async {
    final docs = await _todaysForDoctor(doctorId);
    final current = _withStatus(docs, 'In Consultation');
    if (current.isEmpty) {
      throw StateError('No patient is in consultation.');
    }

    final ref = current.first.reference;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (normalizeStatus(snap.data()?['status']?.toString()) !=
          'In Consultation') {
        throw StateError('That patient is no longer in consultation.');
      }
      tx.update(ref, {
        'status': 'Completed',
        'completedAt': FieldValue.serverTimestamp(),
        ..._actor,
      });
    });
  }

  /// Moves a waiting patient one place down by swapping seq with the
  /// patient right behind them. Tokens stay the same.
  Future<void> skip(String doctorId, String entryId) async {
    final docs = await _todaysForDoctor(doctorId);
    final waiting = _withStatus(docs, 'Waiting');

    final i = waiting.indexWhere((d) => d.id == entryId);
    if (i == -1) throw StateError('This patient is no longer waiting.');
    if (i == waiting.length - 1) {
      throw StateError('This patient is already last in the queue.');
    }

    final a = waiting[i].reference;
    final b = waiting[i + 1].reference;
    await _db.runTransaction((tx) async {
      final sa = await tx.get(a);
      final sb = await tx.get(b);
      if (normalizeStatus(sa.data()?['status']?.toString()) != 'Waiting' ||
          normalizeStatus(sb.data()?['status']?.toString()) != 'Waiting') {
        throw StateError('The queue just changed. Please try again.');
      }
      final seqA = sa.data()?['seq'];
      final seqB = sb.data()?['seq'];
      tx.update(a, {'seq': seqB, ..._actor});
      tx.update(b, {'seq': seqA, ..._actor});
    });
  }

  /// Removes a patient's entry from the queue. The patient's tracking
  /// screen then shows "This queue entry is no longer active."
  Future<void> cancel(String entryId) {
    return _db.collection('queue_entries').doc(entryId).delete();
  }
}