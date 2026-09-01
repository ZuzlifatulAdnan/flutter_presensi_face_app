import 'package:dartz/dartz.dart';

import 'package:flutter_absensi_app/core/config/app_config.dart';
import 'package:flutter_absensi_app/core/helper/device_info_helper.dart';
import 'package:flutter_absensi_app/core/network/api_client.dart';
import 'package:flutter_absensi_app/core/network/api_exception.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_absensi_app/data/models/response/auth_response_model.dart';
import 'package:flutter_absensi_app/data/models/response/user_response_model.dart';

class AuthRemoteDatasource {
  final ApiClient _api = ApiClient.instance;

  /// `POST /api/login`
  ///
  /// Dibatasi 5 percobaan gagal per email+IP per menit; server menjawab 429
  /// dengan sisa detik di pesan. `fcm_token` yang dikirim di sini langsung
  /// disimpan, jadi `/api/update-fcm-token` tidak perlu dipanggil lagi.
  Future<Either<String, AuthResponseModel>> login(
    String username,
    String password, {
    String? fcmToken,
  }) async {
    try {
      final res = await _api.post(
        '/api/login',
        auth: false,
        body: {
          'email': username,
          'password': password,
          'device_name': await DeviceInfoHelper.deviceName(),
          if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
        },
      );

      // Pengaturan aplikasi ikut di `data.app`, jadi tidak perlu request lagi.
      await AppConfig.updateFromEnvelope(res.object('app'));

      // Respons baru menaruh user di `data.user`; endpoint lama di level atas.
      final raw = Map<String, dynamic>.from(res.raw);
      final data = res.data;
      if (data is Map<String, dynamic>) {
        for (final key in const [
          'user',
          'role',
          'work_mode',
          'company',
          'position',
          'default_shift',
          'default_shift_detail',
          'department',
          'token',
        ]) {
          if (!raw.containsKey(key) && data.containsKey(key)) {
            raw[key] = data[key];
          }
        }
      }

      return Right(AuthResponseModel.fromMap(raw));
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// `POST /api/logout` — keluar dari perangkat ini.
  Future<Either<String, String>> logout() async {
    try {
      final res = await _api.post('/api/logout');
      return Right(res.message.isEmpty ? 'Berhasil keluar.' : res.message);
    } on ApiException catch (e) {
      // Token yang sudah tidak valid tetap dianggap berhasil keluar — sesi
      // lokal tetap dibersihkan oleh pemanggil.
      if (e.isUnauthenticated) return const Right('Berhasil keluar.');
      return Left(e.message);
    }
  }

  /// `POST /api/logout-all` — cabut token di semua perangkat.
  Future<Either<String, String>> logoutAll() async {
    try {
      final res = await _api.post('/api/logout-all');
      return Right(res.message.isEmpty
          ? 'Berhasil keluar dari semua perangkat.'
          : res.message);
    } on ApiException catch (e) {
      if (e.isUnauthenticated) {
        return const Right('Berhasil keluar dari semua perangkat.');
      }
      return Left(e.message);
    }
  }

  /// Simpan embedding wajah hasil pendaftaran ke profil pengguna.
  Future<Either<String, UserResponseModel>> updateProfileRegisterFace(
    String embedding,
  ) async {
    try {
      final res = await _api.multipart(
        '/api/update-profile',
        fields: {'face_embedding': embedding},
      );
      final node = res.object('user') ?? res.dataMap;
      final model = UserResponseModel(
        message: res.message,
        user: User.fromMap(node),
      );
      if (model.user != null) {
        await AuthLocalDatasource().updateUser(model.user!);
      }
      return Right(model);
    } on ApiException catch (e) {
      return Left(e.message);
    }
  }

  /// Dipertahankan untuk perangkat yang mendapat token FCM setelah login.
  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await _api.post('/api/update-fcm-token', body: {'fcm_token': fcmToken});
    } on ApiException {
      // Kegagalan menyimpan token notifikasi tidak boleh menghentikan alur.
    }
  }
}
