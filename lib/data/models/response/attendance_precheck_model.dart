import 'dart:convert';

import 'package:flutter_absensi_app/data/models/response/app_settings_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_response_model.dart';

/// Tindakan presensi berikutnya menurut server.
enum NextAction { checkIn, checkOut, done }

extension NextActionX on NextAction {
  String get label => switch (this) {
        NextAction.checkIn => 'Absen Masuk',
        NextAction.checkOut => 'Absen Pulang',
        NextAction.done => 'Presensi Selesai',
      };

  static NextAction parse(String? raw) => switch (raw) {
        'check_in' => NextAction.checkIn,
        'check_out' => NextAction.checkOut,
        _ => NextAction.done,
      };
}

/// Mode kerja yang diizinkan untuk akun ini.
enum WorkMode { wfo, wfh, wfa }

extension WorkModeX on WorkMode {
  String get value => name;

  String get label => switch (this) {
        WorkMode.wfo => 'WFO',
        WorkMode.wfh => 'WFH',
        WorkMode.wfa => 'WFA',
      };

  String get description => switch (this) {
        WorkMode.wfo => 'Bekerja dari kantor',
        WorkMode.wfh => 'Bekerja dari rumah',
        WorkMode.wfa => 'Bekerja dari mana saja',
      };

  /// Mode jarak jauh — foto & catatan bisa jadi wajib, radius tidak divalidasi.
  bool get isRemote => this != WorkMode.wfo;

  static WorkMode parse(String? raw) => switch (raw?.toLowerCase()) {
        'wfh' => WorkMode.wfh,
        'wfa' => WorkMode.wfa,
        _ => WorkMode.wfo,
      };
}

/// Lokasi kantor untuk marker & lingkaran radius di peta.
class AttendanceLocation {
  final int? id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final double? distanceMeters;
  final bool withinRadius;

  const AttendanceLocation({
    this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.distanceMeters,
    this.withinRadius = false,
  });

  factory AttendanceLocation.fromMap(Map<String, dynamic> json) =>
      AttendanceLocation(
        id: (json['id'] as num?)?.toInt(),
        name: json['name']?.toString() ?? 'Lokasi Kantor',
        address: json['address']?.toString(),
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 0,
        distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
        withinRadius: json['within_radius'] == true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'distance_meters': distanceMeters,
        'within_radius': withinRadius,
      };

  /// Jarak siap tampil: `120 m` atau `11,8 km`.
  String get distanceLabel {
    final meters = distanceMeters;
    if (meters == null) return 'Jarak tidak diketahui';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}

class PreCheckWorkMode {
  final WorkMode defaultMode;
  final List<WorkMode> allowed;
  final bool requiresLocation;
  final bool locationReady;

  const PreCheckWorkMode({
    this.defaultMode = WorkMode.wfo,
    this.allowed = const [WorkMode.wfo],
    this.requiresLocation = true,
    this.locationReady = false,
  });

  factory PreCheckWorkMode.fromMap(Map<String, dynamic> json) {
    final raw = json['allowed'];
    final allowed = raw is List
        ? raw.map((e) => WorkModeX.parse(e?.toString())).toSet().toList()
        : <WorkMode>[WorkMode.wfo];
    return PreCheckWorkMode(
      defaultMode: WorkModeX.parse(json['default']?.toString()),
      allowed: allowed.isEmpty ? const [WorkMode.wfo] : allowed,
      requiresLocation: json['requires_location'] != false,
      locationReady: json['location_ready'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'default': defaultMode.value,
        'allowed': allowed.map((e) => e.value).toList(),
        'requires_location': requiresLocation,
        'location_ready': locationReady,
      };
}

/// Aturan wajib-tidaknya foto dan catatan untuk presensi saat ini.
class PreCheckRequirements {
  final bool photoRequired;
  final bool remotePhotoRequired;
  final bool remoteNotesRequired;
  final bool blockMockLocation;
  final double accuracyToleranceMeters;

  const PreCheckRequirements({
    this.photoRequired = false,
    this.remotePhotoRequired = true,
    this.remoteNotesRequired = true,
    this.blockMockLocation = true,
    this.accuracyToleranceMeters = 50,
  });

  factory PreCheckRequirements.fromMap(Map<String, dynamic> json) =>
      PreCheckRequirements(
        photoRequired: json['photo_required'] == true,
        remotePhotoRequired: json['remote_photo_required'] != false,
        remoteNotesRequired: json['remote_notes_required'] != false,
        blockMockLocation: json['block_mock_location'] != false,
        accuracyToleranceMeters:
            (json['accuracy_tolerance_meters'] as num?)?.toDouble() ?? 50,
      );

  Map<String, dynamic> toMap() => {
        'photo_required': photoRequired,
        'remote_photo_required': remotePhotoRequired,
        'remote_notes_required': remoteNotesRequired,
        'block_mock_location': blockMockLocation,
        'accuracy_tolerance_meters': accuracyToleranceMeters,
      };

  /// Foto wajib bila diminta untuk semua mode, atau mode jarak jauh dan
  /// `remote_photo_required` menyala.
  bool photoRequiredFor(WorkMode mode) =>
      photoRequired || (mode.isRemote && remotePhotoRequired);

  /// Catatan aktivitas hanya wajib untuk WFH/WFA.
  bool notesRequiredFor(WorkMode mode) => mode.isRemote && remoteNotesRequired;
}

class PreCheckShift {
  final int? id;
  final String? name;
  final String? startTime;
  final String? endTime;
  final int gracePeriodMinutes;
  final bool isCrossDay;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const PreCheckShift({
    this.id,
    this.name,
    this.startTime,
    this.endTime,
    this.gracePeriodMinutes = 0,
    this.isCrossDay = false,
    this.startsAt,
    this.endsAt,
  });

  factory PreCheckShift.fromMap(Map<String, dynamic> json) => PreCheckShift(
        id: (json['id'] as num?)?.toInt(),
        name: json['name']?.toString(),
        startTime: json['start_time']?.toString(),
        endTime: json['end_time']?.toString(),
        gracePeriodMinutes:
            (json['grace_period_minutes'] as num?)?.toInt() ?? 0,
        isCrossDay: json['is_cross_day'] == true,
        startsAt: json['starts_at'] == null
            ? null
            : DateTime.tryParse(json['starts_at'].toString())?.toLocal(),
        endsAt: json['ends_at'] == null
            ? null
            : DateTime.tryParse(json['ends_at'].toString())?.toLocal(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'grace_period_minutes': gracePeriodMinutes,
        'is_cross_day': isCrossDay,
        'starts_at': startsAt?.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
      };

  String get range {
    if (startTime == null || endTime == null) return '-';
    return '$startTime - $endTime';
  }
}

/// Hasil `GET /api/attendance/pre-check`.
///
/// Satu request memberi semua yang dibutuhkan untuk menggambar peta dan
/// menentukan tombol presensi aktif atau tidak.
class AttendancePreCheck {
  final DateTime? serverTime;
  final String? date;
  final bool isWeekend;
  final bool isHoliday;
  final NextAction nextAction;
  final bool canCheckIn;
  final bool canCheckOut;
  final List<String> blockers;
  final PreCheckWorkMode workMode;
  final PreCheckRequirements requirements;
  final MapSettings map;
  final double? userLatitude;
  final double? userLongitude;
  final AttendanceLocation? nearestLocation;
  final List<AttendanceLocation> locations;
  final PreCheckShift? shift;
  final Attendance? attendance;

  const AttendancePreCheck({
    this.serverTime,
    this.date,
    this.isWeekend = false,
    this.isHoliday = false,
    this.nextAction = NextAction.checkIn,
    this.canCheckIn = false,
    this.canCheckOut = false,
    this.blockers = const [],
    this.workMode = const PreCheckWorkMode(),
    this.requirements = const PreCheckRequirements(),
    this.map = const MapSettings(),
    this.userLatitude,
    this.userLongitude,
    this.nearestLocation,
    this.locations = const [],
    this.shift,
    this.attendance,
  });

  factory AttendancePreCheck.fromJson(String str) =>
      AttendancePreCheck.fromMap(json.decode(str));

  factory AttendancePreCheck.fromMap(Map<String, dynamic> json) {
    Map<String, dynamic> sub(String key) => json[key] is Map
        ? Map<String, dynamic>.from(json[key] as Map)
        : const {};

    final mapNode = sub('map');
    final userPosition = mapNode['user_position'] is Map
        ? Map<String, dynamic>.from(mapNode['user_position'] as Map)
        : const {};

    final rawLocations = json['locations'];
    final nearest = sub('nearest_location');
    final shiftNode = sub('shift');
    final attendanceNode = sub('attendance');

    return AttendancePreCheck(
      serverTime: json['server_time'] == null
          ? null
          : DateTime.tryParse(json['server_time'].toString())?.toLocal(),
      date: json['date']?.toString(),
      isWeekend: json['is_weekend'] == true,
      isHoliday: json['is_holiday'] == true,
      nextAction: NextActionX.parse(json['next_action']?.toString()),
      canCheckIn: json['can_check_in'] == true,
      canCheckOut: json['can_check_out'] == true,
      blockers: json['blockers'] is List
          ? (json['blockers'] as List).map((e) => e.toString()).toList()
          : const [],
      workMode: PreCheckWorkMode.fromMap(sub('work_mode')),
      requirements: PreCheckRequirements.fromMap(sub('requirements')),
      map: MapSettings.fromMap(mapNode),
      userLatitude: (userPosition['latitude'] as num?)?.toDouble(),
      userLongitude: (userPosition['longitude'] as num?)?.toDouble(),
      nearestLocation:
          nearest.isEmpty ? null : AttendanceLocation.fromMap(nearest),
      locations: rawLocations is List
          ? rawLocations
              .whereType<Map>()
              .map((e) =>
                  AttendanceLocation.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      shift: shiftNode.isEmpty ? null : PreCheckShift.fromMap(shiftNode),
      attendance:
          attendanceNode.isEmpty ? null : Attendance.fromMap(attendanceNode),
    );
  }

  /// Tombol presensi aktif untuk [nextAction] saat ini.
  bool get actionEnabled => switch (nextAction) {
        NextAction.checkIn => canCheckIn,
        NextAction.checkOut => canCheckOut,
        NextAction.done => false,
      };

  bool get isDone => nextAction == NextAction.done;

  /// Mode kerja pada absen pulang mengikuti mode saat absen masuk.
  WorkMode get effectiveDefaultMode {
    if (nextAction == NextAction.checkOut && attendance?.workMode != null) {
      return WorkModeX.parse(attendance!.workMode);
    }
    return workMode.defaultMode;
  }

  /// Pilihan mode yang ditampilkan. Saat absen pulang mode terkunci ke mode
  /// absen masuk, jadi tidak ada pilihan yang perlu ditawarkan.
  List<WorkMode> get selectableModes =>
      nextAction == NextAction.checkOut ? const [] : workMode.allowed;

  bool get hasUserPosition => userLatitude != null && userLongitude != null;
}
