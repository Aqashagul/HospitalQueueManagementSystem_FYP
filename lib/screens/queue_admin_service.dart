import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


// >>> KEEP YOUR EXISTING import LINES AT THE TOP, AND ADD THIS ONE:
// import 'dart:async';

/// The queue entries that count for the live queue pages right now:
/// everything from today, plus earlier-day patients who are still
/// Waiting / In Consultation and took their token less than
/// [QueueAdminService.validHours] hours ago.
class QueueWindow {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  const QueueWindow(this.docs);
}

class QueueAdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// A token stays valid this many hours after the patient took it.
  /// Keep this the same as QueueService.validHours in the patient app.
  static const int validHours = 24;

  /// Who did the last action and when (saved on the queue entry).
  Map<String, dynamic> get _actor => {
        'lastActionBy': FirebaseAuth.instance.currentUser?.uid,
        'lastActionAt': FieldValue.serverTimestamp(),
      };

  /// Day key like "20261014". Same format the patient app writes.
  static String dayKeyOf(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// Maps the different spellings of a status to one of
  /// "Waiting", "In Consultation", "Completed", "Expired"
  /// (anything else is returned as-is).
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
      case 'expired':
        return 'Expired';
      default:
        return raw ?? '';
    }
  }

  static int seqOf(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      (d.data()['seq'] as num?)?.toInt() ?? 0;

  /// Joining order across days: the older day first, then seq.
  /// (seq restarts at 1 every day, so seq alone is not enough any more.)
  static int queueOrder(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final dayA = a.data()['dayKey']?.toString() ?? '';
    final dayB = b.data()['dayKey']?.toString() ?? '';
    final byDay = dayA.compareTo(dayB);
    return byDay != 0 ? byDay : seqOf(a).compareTo(seqOf(b));
  }

  /// True for Waiting / In Consultation.
  static bool isActive(String? raw) {
    final s = normalizeStatus(raw);
    return s == 'Waiting' || s == 'In Consultation';
  }

  /// True when the token was taken more than [validHours] hours ago.
  /// joinedAt is null for a moment right after joining: not old then.
  static bool isStale(Map<String, dynamic> data) {
    final t = data['joinedAt'];
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

  /// Does this entry count for the live queue right now?
  static bool inWindow(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final status = data['status']?.toString();
    if (normalizeStatus(status) == 'Expired') return false;
    if (data['dayKey'] == dayKeyOf(DateTime.now())) return true;
    // An earlier day: only a patient who is still waiting / in consultation
    // and whose token is not older than validHours.
    return isActive(status) && !isStale(data);
  }

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

  // ---------------------------------------------------------------------
  // Live streams
  // ---------------------------------------------------------------------

  /// Every entry that counts for the live queues, for all doctors (live).
  Stream<QueueWindow> watchQueueWindow() => _windowStream();

  /// Same, for one doctor.
  Stream<QueueWindow> watchQueueWindowForDoctor(String doctorId) =>
      _windowStream(doctorId: doctorId);

  // Re-subscribes by itself when the date changes, so a page left open
  // overnight keeps showing the new day's patients.
  Stream<QueueWindow> _windowStream({String? doctorId}) {
    late final StreamController<QueueWindow> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    Timer? dayWatcher;
    var startedOnDay = '';

    void start() {
      sub?.cancel();
      startedOnDay = dayKeyOf(DateTime.now());
      Query<Map<String, dynamic>> q = _db.collection('queue_entries');
      if (doctorId != null) q = q.where('doctorId', isEqualTo: doctorId);
      q = q.where('dayKey', whereIn: windowDayKeys());
      sub = q.snapshots().listen(
        (snap) {
          if (controller.isClosed) return;
          controller.add(QueueWindow(snap.docs.where(inWindow).toList()));
        },
        onError: (Object e) {
          if (!controller.isClosed) controller.addError(e);
        },
      );
    }

    controller = StreamController<QueueWindow>(
      onListen: () {
        start();
        dayWatcher = Timer.periodic(const Duration(minutes: 1), (_) {
          if (dayKeyOf(DateTime.now()) != startedOnDay) start();
        });
      },
      onCancel: () {
        dayWatcher?.cancel();
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Every queue entry of today, for all doctors (live).
  /// (Kept for pages that only want today.)
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
  /// (Kept for pages that only want today.)
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
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _queueForDoctor(
    String doctorId,
  ) async {
    final snap = await _db
        .collection('queue_entries')
        .where('doctorId', isEqualTo: doctorId)
        .where('dayKey', whereIn: windowDayKeys())
        .get(const GetOptions(source: Source.server));
    return snap.docs.where(inWindow).toList();
  }

  /// How many patients of this doctor are Waiting / In Consultation right
  /// now (read from the server). Used before deleting a doctor.
  Future<int> activePatientCount(String doctorId) async {
    final docs = await _queueForDoctor(doctorId);
    return docs.where((d) => isActive(d.data()['status']?.toString())).length;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _withStatus(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String status,
  ) {
    return docs
        .where((d) => normalizeStatus(d.data()['status']?.toString()) == status)
        .toList()
      ..sort(queueOrder);
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  /// Calls the next waiting patient (first in line) of this doctor in.
  /// Fails if someone is already in consultation or nobody is waiting.
  Future<void> callNext(String doctorId) async {
    final docs = await _queueForDoctor(doctorId);

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
    final docs = await _queueForDoctor(doctorId);

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
    final docs = await _queueForDoctor(doctorId);
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
    final docs = await _queueForDoctor(doctorId);
    final waiting = _withStatus(docs, 'Waiting');

    final i = waiting.indexWhere((d) => d.id == entryId);
    if (i == -1) throw StateError('This patient is no longer waiting.');
    if (i == waiting.length - 1) {
      throw StateError('This patient is already last in the queue.');
    }
    // seq restarts every day, so two patients from different days cannot
    // swap places by swapping seq.
    if (waiting[i].data()['dayKey'] != waiting[i + 1].data()['dayKey']) {
      throw StateError('This patient cannot be moved further down.');
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

  /// Closes tokens that were never finished: every Waiting / In Consultation
  /// entry older than [validHours] hours becomes "Expired". Only reads the
  /// few active entries (not the whole history). Returns how many it closed.
  /// Needs admin rights, so call it from an admin page.
  Future<int> expireStaleEntries() async {
    final snap = await _db
        .collection('queue_entries')
        .where('status', whereIn: ['Waiting', 'In Consultation'])
        .get(const GetOptions(source: Source.server));

    final stale = snap.docs.where((d) => isStale(d.data())).toList();
    if (stale.isEmpty) return 0;

    final batch = _db.batch();
    // A batch holds at most 500 writes; the rest is closed on the next run.
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