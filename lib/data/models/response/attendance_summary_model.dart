import 'dart:convert';

import 'package:flutter_absensi_app/data/models/response/attendance_precheck_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_response_model.dart';

/// Rekap bulanan dari `GET /api/attendance/summary`.
class AttendanceSummary {
  final int year;
  final int month;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int totalPresent;
  final int onTime;
  final int late;
  final int lateMinutes;
  final int workMinutes;
  final Map<WorkMode, int> byWorkMode;
  final int approvedLeaveDays;

  const AttendanceSummary({
    required this.year,
    required this.month,
    this.periodStart,
    this.periodEnd,
    this.totalPresent = 0,
    this.onTime = 0,
    this.late = 0,
    this.lateMinutes = 0,
    this.workMinutes = 0,
    this.byWorkMode = const {},
    this.approvedLeaveDays = 0,
  });

  factory AttendanceSummary.fromJson(String str) =>
      AttendanceSummary.fromMap(json.decode(str));

  factory AttendanceSummary.fromMap(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final period = json['period'] is Map
        ? Map<String, dynamic>.from(json['period'] as Map)
        : const <String, dynamic>{};

    final modes = <WorkMode, int>{};
    if (json['by_work_mode'] is Map) {
      (json['by_work_mode'] as Map).forEach((key, value) {
        modes[WorkModeX.parse(key.toString())] = asInt(value);
      });
    }

    final now = DateTime.now();
    return AttendanceSummary(
      year: json['year'] == null ? now.year : asInt(json['year']),
      month: json['month'] == null ? now.month : asInt(json['month']),
      periodStart: period['start'] == null
          ? null
          : DateTime.tryParse(period['start'].toString()),
      periodEnd: period['end'] == null
          ? null
          : DateTime.tryParse(period['end'].toString()),
      totalPresent: asInt(json['total_present']),
      onTime: asInt(json['on_time']),
      late: asInt(json['late']),
      lateMinutes: asInt(json['late_minutes']),
      workMinutes: asInt(json['work_minutes']),
      byWorkMode: modes,
      approvedLeaveDays: asInt(json['approved_leave_days']),
    );
  }

  Map<String, dynamic> toMap() => {
        'year': year,
        'month': month,
        'period': {
          'start': periodStart?.toIso8601String(),
          'end': periodEnd?.toIso8601String(),
        },
        'total_present': totalPresent,
        'on_time': onTime,
        'late': late,
        'late_minutes': lateMinutes,
        'work_minutes': workMinutes,
        'by_work_mode': {
          for (final entry in byWorkMode.entries) entry.key.value: entry.value
        },
        'approved_leave_days': approvedLeaveDays,
      };

  int countFor(WorkMode mode) => byWorkMode[mode] ?? 0;

  /// Total jam kerja terformat, mis. `160j 0m`.
  String get workDurationLabel {
    if (workMinutes <= 0) return '0j';
    final hours = workMinutes ~/ 60;
    final minutes = workMinutes % 60;
    if (minutes == 0) return '${hours}j';
    return '${hours}j ${minutes}m';
  }

  String get lateDurationLabel {
    if (lateMinutes <= 0) return '0 menit';
    final hours = lateMinutes ~/ 60;
    final minutes = lateMinutes % 60;
    if (hours == 0) return '$minutes menit';
    return '$hours jam $minutes menit';
  }

  /// Persentase kehadiran tepat waktu, 0..1.
  double get onTimeRatio => totalPresent == 0 ? 0 : onTime / totalPresent;
}

/// Hasil `GET /api/attendance/today`.
class AttendanceTodayStatus {
  final bool checkedIn;
  final bool checkedOut;
  final NextAction nextAction;
  final Attendance? attendance;

  const AttendanceTodayStatus({
    this.checkedIn = false,
    this.checkedOut = false,
    this.nextAction = NextAction.checkIn,
    this.attendance,
  });

  factory AttendanceTodayStatus.fromMap(Map<String, dynamic> json) {
    final node = json['attendance'];
    return AttendanceTodayStatus(
      checkedIn: json['checkedin'] == true || json['checked_in'] == true,
      checkedOut: json['checkedout'] == true || json['checked_out'] == true,
      nextAction: NextActionX.parse(json['next_action']?.toString()),
      attendance: node is Map
          ? Attendance.fromMap(Map<String, dynamic>.from(node))
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'checkedin': checkedIn,
        'checkedout': checkedOut,
        'next_action': nextAction.name,
        'attendance': attendance?.toMap(),
      };
}
