import 'package:dartz/dartz.dart';

import 'package:flutter_absensi_app/core/config/app_config.dart';
import 'package:flutter_absensi_app/core/network/api_client.dart';
import 'package:flutter_absensi_app/core/network/api_exception.dart';
import 'package:flutter_absensi_app/data/models/response/app_settings_model.dart';

class AppSettingsRemoteDatasource {
  final ApiClient _api = ApiClient.instance;

  /// `GET /api/app-settings` — tanpa token, dipanggil saat splash sebelum
  /// login. Nilai yang berhasil dimuat langsung diterapkan ke [AppConfig].
  Future<Either<String, AppSettingsModel>> getAppSettings() async {
    try {
      final res = await _api.get('/api/app-settings', auth: false);
      final model = AppSettingsModel.fromMap(res.dataMap);
      await AppConfig.update(model);
      return Right(model);
    } on ApiException catch (e) {
      // Mode pemeliharaan tetap perlu ditampilkan, bukan dianggap gagal total.
      return Left(e.message);
    }
  }
}
