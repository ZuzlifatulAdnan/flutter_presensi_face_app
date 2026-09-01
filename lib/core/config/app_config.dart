import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_absensi_app/data/models/response/app_settings_model.dart';

/// Pengaturan aplikasi yang aktif saat ini (nama, logo, warna, aturan
/// presensi, versi minimum).
///
/// Diisi dari `/api/app-settings` saat splash dan diperbarui lagi dari
/// `data.app` pada respons login / `/api/me`. Nilai terakhir disimpan di
/// `SharedPreferences` supaya aplikasi tetap tampil benar saat offline.
class AppConfig {
  AppConfig._();

  static const String _prefsKey = 'app_settings';

  /// Sumber kebenaran untuk seluruh UI. Bungkus widget yang perlu ikut
  /// berubah dengan [ValueListenableBuilder].
  static final ValueNotifier<AppSettingsModel> settings =
      ValueNotifier<AppSettingsModel>(AppSettingsModel.fallback);

  static AppSettingsModel get value => settings.value;

  static String get appName => value.appName;

  static AttendanceSettings get attendance => value.attendance;

  static MapSettings get map => value.map;

  /// Muat nilai yang tersimpan sebelum request pertama ke server, supaya
  /// splash tidak berkedip memakai nilai bawaan.
  static Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null && cached.isNotEmpty) {
        settings.value = AppSettingsModel.fromJson(cached);
      }
    } catch (e) {
      debugPrint('[AppConfig] gagal memuat cache: $e');
    }
  }

  static Future<void> update(AppSettingsModel model) async {
    settings.value = model;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, model.toJson());
    } catch (e) {
      debugPrint('[AppConfig] gagal menyimpan cache: $e');
    }
  }

  /// Terapkan `data.app` yang ikut pada respons login / `/api/me`.
  static Future<void> updateFromEnvelope(Map<String, dynamic>? appNode) async {
    if (appNode == null || appNode.isEmpty) return;
    await update(AppSettingsModel.fromMap(appNode));
  }

  /// Versi aplikasi terpasang, diisi dari `pubspec.yaml` saat start.
  static String installedVersion = '0.0.0';

  /// Wajib update bila versi terpasang di bawah versi minimum dan admin
  /// menyalakan `force_update`.
  static bool get mustUpdate {
    final minimum = _minimumVersion;
    if (minimum == null || minimum.isEmpty) return false;
    final behind =
        AppVersionSettings.compare(installedVersion, minimum) < 0;
    return behind && value.version.forceUpdate;
  }

  /// Ada versi lebih baru yang bisa ditawarkan (tanpa memaksa).
  static bool get updateAvailable {
    final latest = _latestVersion;
    if (latest == null || latest.isEmpty) return false;
    return AppVersionSettings.compare(installedVersion, latest) < 0;
  }

  static bool get isUnderMaintenance => value.maintenance.enabled;

  static String? get _minimumVersion => defaultTargetPlatform == TargetPlatform.iOS
      ? value.version.iosMinimum
      : value.version.androidMinimum;

  static String? get _latestVersion => defaultTargetPlatform == TargetPlatform.iOS
      ? value.version.iosLatest
      : value.version.androidLatest;
}
