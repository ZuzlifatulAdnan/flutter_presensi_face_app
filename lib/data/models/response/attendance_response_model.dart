import 'dart:convert';

class AttendanceResponseModel {
  final String? message;
  final List<Attendance>? data;

  /// Paginasi dari `meta` bila `page`/`per_page` dikirim.
  final int? currentPage;
  final int? lastPage;
  final int? total;

  AttendanceResponseModel({
    this.message,
    this.data,
    this.currentPage,
    this.lastPage,
    this.total,
  });

  factory AttendanceResponseModel.fromJson(String str) =>
      AttendanceResponseModel.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory AttendanceResponseModel.fromMap(Map<String, dynamic> json) {
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : const <String, dynamic>{};

    // `data` bisa berupa list langsung, atau objek paginasi Laravel.
    final rawData = json['data'];
    final List list;
    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map && rawData['data'] is List) {
      list = rawData['data'] as List;
    } else {
      list = const [];
    }

    int? asInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return AttendanceResponseModel(
      message: json['message']?.toString(),
      data: list
          .whereType<Map>()
          .map((x) => Attendance.fromMap(Map<String, dynamic>.from(x)))
          .toList(),
      currentPage: asInt(meta['current_page']),
      lastPage: asInt(meta['last_page']),
      total: asInt(meta['total']),
    );
  }

  Map<String, dynamic> toMap() => {
        'message': message,
        'data':
            data == null ? [] : List<dynamic>.from(data!.map((x) => x.toMap())),
      };
}

/// Satu sisi presensi (masuk atau pulang) beserta bukti dan lokasinya.
class AttendanceLeg {
  final String? latlon;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? photoUrl;
  final String? notes;
  final double? distanceMeters;

  const AttendanceLeg({
    this.latlon,
    this.latitude,
    this.longitude,
    this.address,
    this.photoUrl,
    this.notes,
    this.distanceMeters,
  });

  factory AttendanceLeg.fromMap(Map<String, dynamic> json) {
    final coords = json['coordinates'];
    final map = coords is Map ? Map<String, dynamic>.from(coords) : const {};
    return AttendanceLeg(
      latlon: json['latlon']?.toString(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      address: json['address']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      notes: json['notes']?.toString(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'latlon': latlon,
        'coordinates': latitude == null && longitude == null
            ? null
            : {'latitude': latitude, 'longitude': longitude},
        'address': address,
        'photo_url': photoUrl,
        'notes': notes,
        'distance_meters': distanceMeters,
      };

  bool get isEmpty =>
      latlon == null &&
      address == null &&
      photoUrl == null &&
      (notes == null || notes!.isEmpty);

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;
}

class AttendanceShift {
  final int? id;
  final String? name;
  final String? startTime;
  final String? endTime;
  final bool isCrossDay;

  const AttendanceShift({
    this.id,
    this.name,
    this.startTime,
    this.endTime,
    this.isCrossDay = false,
  });

  factory AttendanceShift.fromMap(Map<String, dynamic> json) =>
      AttendanceShift(
        id: json['id'] as int?,
        name: json['name']?.toString(),
        startTime: json['start_time']?.toString(),
        endTime: json['end_time']?.toString(),
        isCrossDay: json['is_cross_day'] == true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'is_cross_day': isCrossDay,
      };

  String get range {
    if (startTime == null || endTime == null) return '-';
    return '$startTime - $endTime';
  }
}

class Attendance {
  final int? id;
  final int? userId;
  final int? shiftId;
  final int? companyId;
  final DateTime? date;
  final String? timeIn;
  final String? timeOut;
  final String? latlonIn;
  final String? latlonOut;
  final String? workMode;
  final String? workModeLabel;
  final String? status;
  final String? statusLabel;
  final bool? isRemote;
  final bool? isCheckedOut;
  final bool? isWeekend;
  final bool? isHoliday;
  final bool? holidayWork;
  final bool? isMockLocation;
  final int? lateMinutes;
  final int? earlyLeaveMinutes;
  final int? workDurationMinutes;
  final AttendanceLeg? checkIn;
  final AttendanceLeg? checkOut;
  final AttendanceShift? shift;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Attendance({
    this.id,
    this.userId,
    this.shiftId,
    this.companyId,
    this.date,
    this.timeIn,
    this.timeOut,
    this.latlonIn,
    this.latlonOut,
    this.workMode,
    this.workModeLabel,
    this.status,
    this.statusLabel,
    this.isRemote,
    this.isCheckedOut,
    this.isWeekend,
    this.isHoliday,
    this.holidayWork,
    this.isMockLocation,
    this.lateMinutes,
    this.earlyLeaveMinutes,
    this.workDurationMinutes,
    this.checkIn,
    this.checkOut,
    this.shift,
    this.createdAt,
    this.updatedAt,
  });

  factory Attendance.fromJson(String str) =>
      Attendance.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory Attendance.fromMap(Map<String, dynamic> json) {
    Map<String, dynamic>? sub(String key) => json[key] is Map
        ? Map<String, dynamic>.from(json[key] as Map)
        : null;

    int? asInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return Attendance(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      shiftId: asInt(json['shift_id']),
      companyId: asInt(json['company_id']),
      date: _parseLocalDate(json['date']),
      timeIn: json['time_in']?.toString(),
      timeOut: json['time_out']?.toString(),
      latlonIn: json['latlon_in']?.toString(),
      latlonOut: json['latlon_out']?.toString(),
      workMode: json['work_mode']?.toString(),
      workModeLabel: json['work_mode_label']?.toString(),
      status: json['status']?.toString(),
      statusLabel: json['status_label']?.toString(),
      isRemote: json['is_remote'] as bool?,
      isCheckedOut: json['is_checked_out'] as bool?,
      isWeekend: json['is_weekend'] as bool?,
      isHoliday: json['is_holiday'] as bool?,
      holidayWork: json['holiday_work'] as bool?,
      isMockLocation: json['is_mock_location'] as bool?,
      lateMinutes: asInt(json['late_minutes']),
      earlyLeaveMinutes: asInt(json['early_leave_minutes']),
      workDurationMinutes: asInt(json['work_duration_minutes']),
      checkIn: sub('check_in') == null
          ? null
          : AttendanceLeg.fromMap(sub('check_in')!),
      checkOut: sub('check_out') == null
          ? null
          : AttendanceLeg.fromMap(sub('check_out')!),
      shift: sub('shift') == null
          ? null
          : AttendanceShift.fromMap(sub('shift')!),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString())?.toLocal(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString())?.toLocal(),
    );
  }

  /// Ekstrak tanggal sebagai wall-clock date (tahun-bulan-tanggal lokal).
  /// Tanggal absen tidak boleh terpengaruh konversi timezone — kalau backend
  /// mengirim ISO dengan offset +07:00, `DateTime.parse` akan normalize ke UTC
  /// dan menggeser tanggal mundur 1 hari saat ditampilkan.
  static DateTime? _parseLocalDate(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(str);
    if (m != null) {
      final y = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final d = int.tryParse(m.group(3)!);
      if (y != null && mo != null && d != null) {
        return DateTime(y, mo, d);
      }
    }
    final dt = DateTime.tryParse(str)?.toLocal();
    if (dt != null) return DateTime(dt.year, dt.month, dt.day);
    return null;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'shift_id': shiftId,
        'company_id': companyId,
        'date': date == null
            ? null
            : '${date!.year.toString().padLeft(4, '0')}-'
                '${date!.month.toString().padLeft(2, '0')}-'
                '${date!.day.toString().padLeft(2, '0')}',
        'time_in': timeIn,
        'time_out': timeOut,
        'latlon_in': latlonIn,
        'latlon_out': latlonOut,
        'work_mode': workMode,
        'work_mode_label': workModeLabel,
        'status': status,
        'status_label': statusLabel,
        'is_remote': isRemote,
        'is_checked_out': isCheckedOut,
        'is_weekend': isWeekend,
        'is_holiday': isHoliday,
        'holiday_work': holidayWork,
        'is_mock_location': isMockLocation,
        'late_minutes': lateMinutes,
        'early_leave_minutes': earlyLeaveMinutes,
        'work_duration_minutes': workDurationMinutes,
        'check_in': checkIn?.toMap(),
        'check_out': checkOut?.toMap(),
        'shift': shift?.toMap(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Label siap tampil. Utamakan `status_label` dari server, jatuh ke
  /// pemetaan lokal untuk respons endpoint lama.
  String get displayStatus {
    if (statusLabel != null && statusLabel!.isNotEmpty) return statusLabel!;
    switch (status) {
      case 'on_time':
        return 'Tepat Waktu';
      case 'late':
        return 'Terlambat';
      case 'absent':
        return 'Tidak Hadir';
      default:
        return status ?? '-';
    }
  }

  String get displayWorkMode {
    if (workModeLabel != null && workModeLabel!.isNotEmpty) {
      return workModeLabel!;
    }
    switch (workMode) {
      case 'wfh':
        return 'WFH';
      case 'wfa':
        return 'WFA';
      case 'wfo':
        return 'WFO';
      default:
        return '-';
    }
  }

  bool get isRemoteMode => isRemote ?? (workMode == 'wfh' || workMode == 'wfa');

  bool get hasCheckedOut =>
      isCheckedOut ?? (timeOut != null && timeOut!.isNotEmpty);

  /// Durasi kerja terformat, mis. `8j 15m`.
  String get workDurationLabel {
    final minutes = workDurationMinutes;
    if (minutes == null || minutes <= 0) return '-';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${rest}m';
    return '${hours}j ${rest}m';
  }
}
