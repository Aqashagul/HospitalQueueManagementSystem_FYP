import 'package:queue_management_system/data/appdata_store.dart';


class AnalyticsController {
//1 graph
  Map<String, List> getWeeklyPatientFlow() {
    final patients = AppdataStore().patient;
    const dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    final served = List.filled(7, 0);
    final waiting = List.filled(7, 0);

    for (final p in patients) {
      final weekdayIndex = p.registrationTime.weekday - 1; // Dart: Mon=1...Sun=7 -> 0-indexed
      if (p.status == "Completed") {
        served[weekdayIndex]++;
      } else if (p.status == "Waiting") {
        waiting[weekdayIndex]++;
      }
    }

    return {
      "days": dayNames,
      "served": served.map((e) => e.toDouble()).toList(),
      "waiting": waiting.map((e) => e.toDouble()).toList(),
    };
  }

  //2. Peak Hour Patient Count
  Map<String, List> getPeakHourData() {
    final patients = AppdataStore().patient;
    final hours = List.generate(9, (i) => 9 + i); // 9,10,...,17
    final counts = List.filled(9, 0);

    for (final p in patients) {
      final hour = p.registrationTime.hour;
      final index = hours.indexOf(hour);
      if (index != -1) counts[index]++;
    }

    return {
      "hours": hours.map((h) => h == 12 ? "12PM" : (h > 12 ? "${h - 12}PM" : "${h}AM")).toList(),
      "counts": counts.map((e) => e.toDouble()).toList(),
    };
  }

  // 3. Patients by Department
  List<Map<String, dynamic>> getPatientsByDepartment() {
    final patients = AppdataStore().patient;
    final departments = AppdataStore().departments;

    final result = <Map<String, dynamic>>[];
    for (final dept in departments) {
      final count = patients.where((p) => p.department == dept.name).length;
      if (count > 0) {
        final percentage = (count / patients.length) * 100;
        result.add({"name": dept.name, "percentage": percentage});
      }
    }
    return result;
  }

  // 4. Completed vs Cancelled — department-wise comparison 
  Map<String, List> getCompletedVsCancelled() {
    final patients = AppdataStore().patient;
    final departments = AppdataStore().departments;

    final completed = <double>[];
    final cancelled = <double>[];
    final deptNames = <String>[];

    for (final dept in departments) {
      final deptPatients = patients.where((p) => p.department == dept.name);
      final completedCount = deptPatients.where((p) => p.status == "Completed").length;
      final cancelledCount = deptPatients.where((p) => p.status == "Cancelled").length;

      if (completedCount > 0 || cancelledCount > 0) {
        deptNames.add(dept.name);
        completed.add(completedCount.toDouble());
        cancelled.add(cancelledCount.toDouble());
      }
    }

    return {"departments": deptNames, "completed": completed, "cancelled": cancelled};
  }

  // 5. Average Waiting Time by Doctor 
  List<Map<String, dynamic>> getAvgWaitingTimeByDoctor() {
    final patients = AppdataStore().patient;
    final doctors = AppdataStore().doctors;
    final now = DateTime.now();

    final result = <Map<String, dynamic>>[];
    for (final doctor in doctors) {
      final activePatients = patients.where(
        (p) => p.doctor == doctor.name && (p.status == "Waiting" || p.status == "In Consultation"),
      );

      if (activePatients.isEmpty) continue;

      final totalMinutes = activePatients.fold<int>(
        0,
        (sum, p) => sum + now.difference(p.registrationTime).inMinutes,
      );
      final avgMinutes = totalMinutes ~/ activePatients.length;

      result.add({"name": doctor.name, "minutes": avgMinutes});
    }
    return result;
  }

  // 6. Doctor Workload — percentage score based on active queue + handled count 
  // Formula: workload = (active queue size * 10) + (patients handled today * 3), capped at 100
  // Weights (10, 3) 
  List<Map<String, dynamic>> getDoctorWorkload() {
    final patients = AppdataStore().patient;
    final doctors = AppdataStore().doctors;

    final result = <Map<String, dynamic>>[];
    for (final doctor in doctors) {
      final docPatients = patients.where((p) => p.doctor == doctor.name);

      final activeQueueSize =
          docPatients.where((p) => p.status == "Waiting" || p.status == "In Consultation").length;
      final handledToday = docPatients.where((p) => p.status == "Completed").length;

      final rawScore = (activeQueueSize * 10) + (handledToday * 3);
      final workload = rawScore > 100 ? 100 : rawScore;

      if (docPatients.isNotEmpty) {
        result.add({"name": doctor.name, "workload": workload.toDouble()});
      }
    }
    return result;
  }

  //7. Peak Hours Heatmap, day-of-week x hour-of-day grid 
  List<List<int>> getHeatmapData() {
    final patients = AppdataStore().patient;
    const hours = [9, 10, 11, 12, 13, 14, 15, 16, 17]; // 9AM-5PM

    // grid[dayIndex][hourIndex], day: Mon=0 ... Sun=6
    final grid = List.generate(7, (_) => List.filled(hours.length, 0));

    for (final p in patients) {
      final dayIndex = p.registrationTime.weekday - 1;
      final hourIndex = hours.indexOf(p.registrationTime.hour);
      if (hourIndex != -1) {
        grid[dayIndex][hourIndex]++;
      }
    }
    return grid;
  }

  // 8. Bottleneck Identifier — inflow per hour + avg wait per hour 

  Map<String, List> getBottleneckData() {
    final patients = AppdataStore().patient;
    final hours = List.generate(9, (i) => 9 + i);
    final now = DateTime.now();

    final inflow = List.filled(9, 0);
    final waitSums = List.filled(9, 0);
    final waitCounts = List.filled(9, 0);

    for (final p in patients) {
      final hour = p.registrationTime.hour;
      final index = hours.indexOf(hour);
      if (index == -1) continue;

      inflow[index]++;

      if (p.status == "Waiting" || p.status == "In Consultation") {
        waitSums[index] += now.difference(p.registrationTime).inMinutes;
        waitCounts[index]++;
      }
    }

    final avgWait = List.generate(
      9,
      (i) => waitCounts[i] == 0 ? 0 : waitSums[i] ~/ waitCounts[i],
    );

    return {
      "hours": hours.map((h) => h == 12 ? "12PM" : (h > 12 ? "${h - 12}PM" : "${h}AM")).toList(),
      "inflow": inflow.map((e) => e.toDouble()).toList(),
      "avgWait": avgWait.map((e) => e.toDouble()).toList(),
    };
  }
}