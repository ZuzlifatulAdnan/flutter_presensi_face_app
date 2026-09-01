import 'package:dartz/dartz.dart';

import 'package:flutter_absensi_app/core/network/api_client.dart';
import 'package:flutter_absensi_app/core/network/api_exception.dart';
import 'package:flutter_absensi_app/data/models/request/create_leave_request_model.dart';
import 'package:flutter_absensi_app/data/models/response/leave_balance_response_model.dart';
import 'package:flutter_absensi_app/data/models/response/leave_response_model.dart';
import 'package:flutter_absensi_app/data/models/response/leave_type_response_model.dart';

class LeaveRemoteDatasource {
  final ApiClient _api = ApiClient.instance;

  /// `GET /api/leave-types`
  Future<Either<String, LeaveTypeResponseModel>> getLeaveTypes() async {
    try {
      final res = await _api.get('/api/leave-types');
      return Right(LeaveTypeResponseModel.fromMap(res.raw));
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `GET /api/leave-balance?year=` — sisa kuota per jenis izin.
  ///
  /// Jalur lama `/api/leaves/balance` tetap dicoba supaya aplikasi bekerja di
  /// server yang belum diperbarui.
  Future<Either<String, LeaveBalanceResponseModel>> getLeaveBalance({
    String? year,
  }) async {
    final query = {'year': year};
    try {
      final res = await _api.get('/api/leave-balance', query: query);
      return Right(LeaveBalanceResponseModel.fromMap(res.raw));
    } on ApiException catch (e) {
      if (!e.isNotFound) return Left(e.message);
    }

    try {
      final res = await _api.get('/api/leaves/balance', query: query);
      return Right(LeaveBalanceResponseModel.fromMap(res.raw));
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `GET /api/leaves` — hanya pengajuan milik sendiri.
  ///
  /// Tanpa [page]/[perPage] server mengirim maks 300 data terbaru.
  Future<Either<String, LeaveResponseModel>> getLeaves({
    String? status,
    int? year,
    int? page,
    int? perPage,
  }) async {
    try {
      final res = await _api.get('/api/leaves', query: {
        'status': status,
        'year': year,
        'page': page,
        'per_page': perPage,
      });
      return Right(LeaveResponseModel.fromMap(res.raw));
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `GET /api/leaves/{id}` — pemilik, atau admin/manager/hr.
  Future<Either<String, Leave>> getLeaveDetail(int id) async {
    try {
      final res = await _api.get('/api/leaves/$id');
      return Right(Leave.fromMap(res.dataMap));
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `POST /api/leaves` — ajukan izin/cuti, `multipart/form-data` bila ada
  /// lampiran.
  ///
  /// `total_days` dihitung server (mengecualikan akhir pekan dan hari libur),
  /// jadi aplikasi tidak menghitungnya sendiri.
  Future<Either<String, Leave>> createLeave(
    CreateLeaveRequestModel request,
  ) async {
    final invalid = CreateLeaveRequestModel.validateAttachment(request.attachment);
    if (invalid != null) return Left(invalid);

    try {
      final res = await _api.multipart(
        '/api/leaves',
        fields: request.toMap(),
        files: [if (request.attachment != null) request.attachment!],
      );
      return Right(Leave.fromMap(res.dataMap));
    } on ApiException catch (e) {
      return Left(_leaveError(e));
    }
  }

  /// `POST /api/leaves/{id}` — ubah pengajuan yang masih `pending`.
  ///
  /// Memakai POST (bukan PUT) karena PHP tidak mem-parse multipart pada PUT.
  Future<Either<String, Leave>> updateLeave(
    int id,
    CreateLeaveRequestModel request,
  ) async {
    final invalid = CreateLeaveRequestModel.validateAttachment(request.attachment);
    if (invalid != null) return Left(invalid);

    try {
      final res = await _api.multipart(
        '/api/leaves/$id',
        fields: request.toMap(),
        files: [if (request.attachment != null) request.attachment!],
      );
      return Right(Leave.fromMap(res.dataMap));
    } on ApiException catch (e) {
      return Left(_leaveError(e));
    }
  }

  /// `POST /api/leaves/{id}/cancel`
  Future<Either<String, String>> cancelLeave(int id) async {
    try {
      final res = await _api.post('/api/leaves/$id/cancel');
      return Right(res.message.isEmpty
          ? 'Pengajuan berhasil dibatalkan.'
          : res.message);
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `POST /api/leaves/{id}/approve` — khusus admin/manager/hr.
  Future<Either<String, String>> approveLeave(int id, {String? notes}) async {
    try {
      final res = await _api.post(
        '/api/leaves/$id/approve',
        body: {if (notes != null && notes.isNotEmpty) 'notes': notes},
      );
      return Right(
          res.message.isEmpty ? 'Pengajuan disetujui.' : res.message);
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `POST /api/leaves/{id}/reject` — `notes` wajib berisi alasan penolakan.
  Future<Either<String, String>> rejectLeave(int id, String notes) async {
    try {
      final res = await _api.post(
        '/api/leaves/$id/reject',
        body: {'notes': notes},
      );
      return Right(res.message.isEmpty ? 'Pengajuan ditolak.' : res.message);
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// Sisipkan sisa kuota ke pesan penolakan agar pengguna tahu berapa yang
  /// tersisa tanpa membuka halaman lain.
  String _leaveError(ApiException e) {
    final remaining = e.numberFrom('remaining_days');
    final requested = e.numberFrom('requested_days');
    if (remaining == null || requested == null) return e.message;
    return '${e.message} Sisa kuota ${remaining.round()} hari, '
        'diajukan ${requested.round()} hari.';
  }
}
