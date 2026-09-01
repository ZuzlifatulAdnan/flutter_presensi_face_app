import 'package:dartz/dartz.dart';

import 'package:flutter_absensi_app/core/network/api_client.dart';
import 'package:flutter_absensi_app/core/network/api_exception.dart';
import 'package:flutter_absensi_app/data/models/request/checkinout_request_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_precheck_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_response_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_summary_model.dart';
import 'package:flutter_absensi_app/data/models/response/checkinout_response_model.dart';
import 'package:flutter_absensi_app/data/models/response/company_response_model.dart';

class AttendanceRemoteDatasource {
  final ApiClient _api = ApiClient.instance;

  // ---------------------------------------------------------------------------
  // Peta & kelayakan presensi
  // ---------------------------------------------------------------------------

  /// `GET /api/attendance/pre-check`
  ///
  /// Satu request memberi semua yang dibutuhkan halaman presensi: konfigurasi
  /// peta, daftar kantor, jarak, mode kerja yang boleh dipakai, syarat foto &
  /// catatan, serta apakah tombol presensi boleh aktif.
  ///
  /// [latitude]/[longitude] boleh null bila izin lokasi belum diberikan —
  /// daftar kantor tetap dikirim dengan `distance_meters` bernilai null.
  Future<Either<String, AttendancePreCheck>> preCheck({
    double? latitude,
    double? longitude,
  }) async {
    try {
      final res = await _api.get('/api/attendance/pre-check', query: {
        'latitude': latitude,
        'longitude': longitude,
      });
      return Right(AttendancePreCheck.fromMap(res.dataMap));
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `GET /api/attendance/locations` — hanya bagian peta, untuk halaman peta
  /// yang berdiri sendiri.
  Future<Either<String, List<AttendanceLocation>>> getLocations({
    double? latitude,
    double? longitude,
  }) async {
    try {
      final res = await _api.get('/api/attendance/locations', query: {
        'latitude': latitude,
        'longitude': longitude,
      });
      final raw = res.dataMap['locations'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) =>
                  AttendanceLocation.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : <AttendanceLocation>[];
      return Right(list);
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `GET /api/companies` — semua kantor yang boleh dipakai user.
  Future<Either<String, List<AttendanceLocation>>> getCompanies() async {
    try {
      final res = await _api.get('/api/companies');
      return Right(res.dataList.map(AttendanceLocation.fromMap).toList());
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `GET /api/company` — profil kantor utama (endpoint lama, tetap dipakai
  /// oleh layar yang belum berpindah ke `pre-check`).
  Future<Either<String, CompanyResponseModel>> getCompanyProfile() async {
    try {
      final res = await _api.get('/api/company');
      return Right(CompanyResponseModel.fromMap(res.raw));
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  // ---------------------------------------------------------------------------
  // Status hari ini
  // ---------------------------------------------------------------------------

  /// `GET /api/attendance/today`, dengan fallback ke `/api/is-checkin`.
  Future<Either<String, AttendanceTodayStatus>> getTodayStatus() async {
    try {
      final res = await _api.get('/api/attendance/today');
      return Right(AttendanceTodayStatus.fromMap(res.dataMap));
    } on ApiException catch (e) {
      if (!e.isNotFound) return Left(e.message);
    }

    // Server lama belum punya `/attendance/today`.
    try {
      final res = await _api.get('/api/is-checkin');
      return Right(AttendanceTodayStatus.fromMap(res.raw));
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// Bentuk lama `(checkedin, checkedout)` yang masih dipakai `IsCheckedinBloc`.
  Future<Either<String, (bool, bool)>> isCheckedin() async {
    final result = await getTodayStatus();
    return result.map((status) => (status.checkedIn, status.checkedOut));
  }

  // ---------------------------------------------------------------------------
  // Presensi masuk & pulang
  // ---------------------------------------------------------------------------

  /// `POST /api/attendance/check-in` (alias lama `POST /api/checkin`).
  Future<Either<String, CheckInOutResponseModel>> checkin(
    CheckInOutRequestModel data,
  ) =>
      _submitAttendance(
        path: '/api/attendance/check-in',
        legacyPath: '/api/checkin',
        data: data,
        fallback: 'Gagal melakukan absen masuk',
      );

  /// `POST /api/attendance/check-out` (alias lama `POST /api/checkout`).
  ///
  /// `work_mode` tidak dikirim — server memakai mode dari data absen masuk.
  Future<Either<String, CheckInOutResponseModel>> checkout(
    CheckInOutRequestModel data,
  ) =>
      _submitAttendance(
        path: '/api/attendance/check-out',
        legacyPath: '/api/checkout',
        data: CheckInOutRequestModel(
          latitude: data.latitude,
          longitude: data.longitude,
          photo: data.photo,
          notes: data.notes,
          address: data.address,
          isMockLocation: data.isMockLocation,
          deviceInfo: data.deviceInfo,
          accuracy: data.accuracy,
        ),
        fallback: 'Gagal melakukan absen pulang',
      );

  Future<Either<String, CheckInOutResponseModel>> _submitAttendance({
    required String path,
    required String legacyPath,
    required CheckInOutRequestModel data,
    required String fallback,
  }) async {
    Future<Either<String, CheckInOutResponseModel>> send(String url) async {
      final res = await _api.multipart(
        url,
        fields: data.toMap(),
        files: [if (data.photo != null) data.photo!],
      );
      return Right(CheckInOutResponseModel.fromMap(res.raw));
    }

    try {
      return await send(path);
    } on ApiException catch (e) {
      // Server lama belum punya endpoint baru — coba alias lamanya.
      if (e.isNotFound) {
        try {
          return await send(legacyPath);
        } on ApiException catch (legacy) {
          return Left(_attendanceError(legacy, fallback));
        }
      }
      return Left(_attendanceError(e, fallback));
    }
  }

  /// Perkaya pesan penolakan dengan konteks dari `data`, mis. jarak ke kantor
  /// saat pengguna berada di luar radius.
  String _attendanceError(ApiException e, String fallback) {
    final message = e.message.isNotEmpty ? e.message : fallback;
    final distance = e.numberFrom('distance_meters');
    if (distance == null) return message;

    final radius = e.numberFrom('radius_meters');
    final jarak = distance < 1000
        ? '${distance.round()} m'
        : '${(distance / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
    final buffer = StringBuffer(message)..write(' Jarak Anda $jarak');
    if (radius != null) {
      buffer.write(' dari kantor (radius maksimal ${radius.round()} m).');
    } else {
      buffer.write(' dari kantor.');
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Riwayat & rekap
  // ---------------------------------------------------------------------------

  /// `GET /api/attendance/history` (alias lama `GET /api/api-attendances`).
  ///
  /// Tanpa [page]/[perPage] server mengirim maksimal 500 data terbaru
  /// sekaligus, sesuai perilaku lama.
  Future<Either<String, AttendanceResponseModel>> getAttendances({
    String? date,
    String? from,
    String? to,
    int? month,
    int? year,
    String? status,
    String? workMode,
    int? page,
    int? perPage,
  }) async {
    final query = <String, dynamic>{
      'date': date,
      'from': from,
      'to': to,
      'month': month,
      'year': year,
      'status': status,
      'work_mode': workMode,
      'page': page,
      'per_page': perPage,
    };

    try {
      final res = await _api.get('/api/attendance/history', query: query);
      return Right(AttendanceResponseModel.fromMap(res.raw));
    } on ApiException catch (e) {
      if (!e.isNotFound) return Left(e.message);
    }

    try {
      final res = await _api.get('/api/api-attendances', query: query);
      return Right(AttendanceResponseModel.fromMap(res.raw));
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// Riwayat untuk satu tanggal.
  Future<Either<String, AttendanceResponseModel>> getAttendance(String date) =>
      getAttendances(date: date);

  /// Seluruh riwayat terbaru (tanpa filter).
  Future<Either<String, AttendanceResponseModel>> getAllAttendances() =>
      getAttendances();

  /// `GET /api/attendance/summary?month=&year=` — rekap bulanan untuk kartu
  /// statistik di beranda dan halaman riwayat.
  Future<Either<String, AttendanceSummary>> getSummary({
    int? month,
    int? year,
  }) async {
    final now = DateTime.now();
    try {
      final res = await _api.get('/api/attendance/summary', query: {
        'month': month ?? now.month,
        'year': year ?? now.year,
      });
      return Right(AttendanceSummary.fromMap(res.dataMap));
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }
}
