import 'package:cloud_firestore/cloud_firestore.dart';

/// Queue entries as they come from Firestore.
typedef QueueDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

/// How many patients one doctor can comfortably see in a day. The Doctor
/// Workload chart shows (patients / (capacity x days)) as a percentage.
/// Change this number to match your hospital.
const int kDailyPatientCapacity = 20;

/// Turns queue entries from Firestore into the numbers the Reports charts
/// need. Pure calculations only: no widgets, no Firestore calls.
class AnalyticsData {
  AnalyticsData._();

  static String _statusOf(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      (d.data()['status']?.toString() ?? '').toLowerCase();

  static bool _isCompleted(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final s = _statusOf(d);
    return s == 'completed' || s == 'done';
  }

  static bool _isCancelled(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      _statusOf(d) == 'cancelled';

  // joinedAt is null for a moment right after a patient joins (the server
  // timestamp is still being written), so treat that as "now".
  static DateTime _joinedOf(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final t = d.data()['joinedAt'];
    return t is Timestamp ? t.toDate() : DateTime.now();
  }

  static String _dayKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static String _hourLabel(int h) =>
      h == 12 ? '12PM' : (h > 12 ? '${h - 12}PM' : '${h}AM');

  /// Patients served (completed) per day for the last 7 days, oldest first.
  /// Returns {"days": List<String>, "served": List<double>}.
  static Map<String, dynamic> weeklyPatientFlow(QueueDocs docs) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final days = <String>[];
    final served = <double>[];
    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final key = _dayKey(day);
      days.add(names[day.weekday - 1]);
      served.add(
        docs
            .where((d) => d.data()['dayKey'] == key && _isCompleted(d))
            .length
            .toDouble(),
      );
    }
    return {'days': days, 'served': served};
  }

  /// Tokens taken per hour (8 AM - 5 PM).
  /// Returns {"hours": List<String>, "counts": List<double>}.
  static Map<String, dynamic> peakHourData(QueueDocs docs) {
    final perHour = <int, int>{for (int h = 8; h <= 17; h++) h: 0};
    for (final d in docs) {
      final hour = _joinedOf(d).hour;
      if (perHour.containsKey(hour)) perHour[hour] = perHour[hour]! + 1;
    }

    final hours = <String>[];
    final counts = <double>[];
    perHour.forEach((hour, count) {
      hours.add(_hourLabel(hour));
      counts.add(count.toDouble());
    });
    return {'hours': hours, 'counts': counts};
  }

  /// Each department's share of all tokens, biggest first.
  /// Returns a list of {"name": String, "percentage": double}.
  static List<Map<String, dynamic>> patientsByDepartment(QueueDocs docs) {
    final counts = <String, int>{};
    for (final d in docs) {
      final dep = d.data()['department']?.toString() ?? '';
      if (dep.isEmpty) continue;
      counts[dep] = (counts[dep] ?? 0) + 1;
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return [];

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) => {'name': e.key, 'percentage': e.value / total * 100})
        .toList();
  }

  /// Completed and cancelled tokens per department (A to Z).
  /// Returns {"departments": List<String>, "completed": List<double>,
  ///          "cancelled": List<double>}.
  static Map<String, dynamic> completedVsCancelled(QueueDocs docs) {
    final completed = <String, int>{};
    final cancelled = <String, int>{};

    for (final d in docs) {
      final dep = d.data()['department']?.toString() ?? '';
      if (dep.isEmpty) continue;
      completed.putIfAbsent(dep, () => 0);
      cancelled.putIfAbsent(dep, () => 0);
      if (_isCompleted(d)) completed[dep] = completed[dep]! + 1;
      if (_isCancelled(d)) cancelled[dep] = cancelled[dep]! + 1;
    }

    final names = completed.keys.toList()..sort();
    return {
      'departments': names,
      'completed': names.map((n) => completed[n]!.toDouble()).toList(),
      'cancelled': names.map((n) => cancelled[n]!.toDouble()).toList(),
    };
  }

  /// Workload % per doctor: tokens in the period divided by
  /// (kDailyPatientCapacity x number of days), capped at 100. Busiest first.
  /// [doctors] maps doctorId -> doctor name. Returns a list of
  /// {"name": String, "workload": double}.
  static List<Map<String, dynamic>> doctorWorkload(
    QueueDocs docs,
    Map<String, String> doctors,
    int days,
  ) {
    final capacity = kDailyPatientCapacity * (days < 1 ? 1 : days);

    final result = doctors.entries.map((doctor) {
      final count = docs.where((d) => d.data()['doctorId'] == doctor.key).length;
      final percent = (count / capacity * 100).clamp(0, 100).toDouble();
      return {'name': doctor.value, 'workload': percent};
    }).toList();

    result.sort(
      (a, b) => (b['workload'] as double).compareTo(a['workload'] as double),
    );
    return result;
  }
}