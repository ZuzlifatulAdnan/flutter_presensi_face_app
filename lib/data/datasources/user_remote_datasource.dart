import 'package:dartz/dartz.dart';

import 'package:flutter_absensi_app/core/config/app_config.dart';
import 'package:flutter_absensi_app/core/network/api_client.dart';
import 'package:flutter_absensi_app/core/network/api_exception.dart';
import 'package:flutter_absensi_app/data/models/request/user_request_model.dart';
import 'package:flutter_absensi_app/data/models/response/auth_response_model.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';

class UserRemoteDatasource {
  final ApiClient _api = ApiClient.instance;

  /// `GET /api/me` — profil pengguna + pengaturan aplikasi.
  ///
  /// Jatuh kembali ke `/api/api-user/{id}` untuk server yang belum
  /// menyediakan `/me`.
  Future<Either<String, User>> getUser() async {
    try {
      final res = await _api.get('/api/me');
      await AppConfig.updateFromEnvelope(res.object('app'));
      final node = res.object('user') ?? res.dataMap;
      final user = User.fromMap(node);
      await AuthLocalDatasource().updateUser(user);
      return Right(user);
    } on ApiException catch (e) {
      if (!e.isNotFound) return Left(e.message);
    }

    final authData = await AuthLocalDatasource().getAuthData();
    final id = authData?.user?.id;
    if (id == null) return const Left('Sesi tidak ditemukan. Silakan masuk kembali.');

    try {
      final res = await _api.get('/api/api-user/$id');
      final user = User.fromMap(res.dataMap);
      await AuthLocalDatasource().updateUser(user);
      return Right(user);
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `POST /api/api-user/edit` — `multipart/form-data`.
  ///
  /// Field `id` pada body diabaikan server; endpoint selalu mengubah pemilik
  /// token. Foto lama otomatis dihapus dari storage saat diganti.
  Future<Either<String, User>> updateProfile(
    UserRequestModel model,
    int id,
  ) async {
    try {
      final image = model.image;
      final files = <UploadFile>[];
      if (image != null) {
        files.add(
          UploadFile.bytes(
            'image',
            await image.readAsBytes(),
            filename: image.name.isEmpty ? 'profile.jpg' : image.name,
          ),
        );
      }

      final res = await _api.multipart(
        '/api/api-user/edit',
        fields: model.toMap(),
        files: files,
      );

      final node = res.object('user') ?? res.dataMap;
      final user = User.fromMap(node);
      await AuthLocalDatasource().updateUser(user);
      return Right(user);
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `POST /api/change-password` (alias lama
  /// `POST /api/api-user/update-password`).
  ///
  /// Password baru minimal 8 karakter, mengandung huruf dan angka, dan berbeda
  /// dari password lama. Setelah berhasil, token perangkat lain dicabut
  /// sementara token perangkat ini tetap valid.
  Future<Either<String, String>> updatePassword(
    String oldPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    final body = {
      'current_password': oldPassword,
      'password': newPassword,
      'password_confirmation': confirmPassword,
    };

    try {
      final res = await _api.post('/api/change-password', body: body);
      return Right(res.message.isEmpty
          ? 'Password berhasil diubah. Perangkat lain telah dikeluarkan.'
          : res.message);
    } on ApiException catch (e) {
      if (!e.isNotFound) return Left(e.message);
    }

    try {
      final res =
          await _api.post('/api/api-user/update-password', body: body);
      return Right(
          res.message.isEmpty ? 'Password berhasil diubah.' : res.message);
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// Aturan password baru sesuai validasi server, dipakai untuk memberi
  /// umpan balik langsung di form sebelum request dikirim.
  static String? validateNewPassword(String password, String current) {
    if (password.length < 8) {
      return 'Password baru minimal 8 karakter.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
      return 'Password baru harus mengandung huruf.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password baru harus mengandung angka.';
    }
    if (password == current) {
      return 'Password baru harus berbeda dari password lama.';
    }
    return null;
  }
}
