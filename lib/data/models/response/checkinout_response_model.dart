import 'dart:convert';

import 'package:flutter_absensi_app/data/models/response/attendance_response_model.dart';

// `Attendance` dipakai bersama dengan riwayat presensi supaya respons check-in
// dan riwayat punya bentuk yang sama (termasuk foto, catatan, dan jarak).
export 'package:flutter_absensi_app/data/models/response/attendance_response_model.dart'
    show Attendance, AttendanceLeg, AttendanceShift;

class CheckInOutResponseModel {
  final String? message;
  final Attendance? attendance;

  CheckInOutResponseModel({
    this.message,
    this.attendance,
  });

  factory CheckInOutResponseModel.fromJson(String str) =>
      CheckInOutResponseModel.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  /// Respons baru mengirim presensi di `data`; endpoint lama di `attendance`.
  /// Keduanya diterima supaya build lama dan baru sama-sama jalan.
  factory CheckInOutResponseModel.fromMap(Map<String, dynamic> json) {
    final node = json['data'] is Map ? json['data'] : json['attendance'];
    return CheckInOutResponseModel(
      message: json['message']?.toString(),
      attendance: node is Map
          ? Attendance.fromMap(Map<String, dynamic>.from(node))
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'message': message,
        'attendance': attendance?.toMap(),
      };
}
