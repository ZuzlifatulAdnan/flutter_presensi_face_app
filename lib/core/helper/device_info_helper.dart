import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Identitas perangkat & aplikasi.
///
/// Dipakai untuk `device_name` saat login, `device_info` saat presensi, dan
/// pengecekan versi minimum dari `/api/app-settings`. Semua pembacaan
/// di-cache karena nilainya tidak berubah selama aplikasi berjalan.
class DeviceInfoHelper {
  DeviceInfoHelper._();

  static String? _deviceName;
  static String? _deviceInfo;
  static PackageInfo? _packageInfo;

  /// Nama singkat perangkat, mis. `Pixel 8`.
  static Future<String> deviceName() async {
    if (_deviceName != null) return _deviceName!;
    await _load();
    return _deviceName!;
  }

  /// Deskripsi lengkap perangkat, mis. `Pixel 8 / Android 15`.
  static Future<String> deviceInfo() async {
    if (_deviceInfo != null) return _deviceInfo!;
    await _load();
    return _deviceInfo!;
  }

  /// Versi aplikasi terpasang dari `pubspec.yaml`, mis. `1.4.0`.
  static Future<String> appVersion() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!.version;
  }

  static Future<String> appBuildNumber() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!.buildNumber;
  }

  static Future<void> _load() async {
    var name = 'Perangkat';
    var info = 'Perangkat';

    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await plugin.webBrowserInfo;
        name = web.browserName.name;
        info = '$name / Web';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final android = await plugin.androidInfo;
            name = android.model;
            info = '${android.manufacturer} $name / Android '
                '${android.version.release}';
            break;
          case TargetPlatform.iOS:
            final ios = await plugin.iosInfo;
            name = ios.name;
            info = '${ios.utsname.machine} / iOS ${ios.systemVersion}';
            break;
          case TargetPlatform.macOS:
            final mac = await plugin.macOsInfo;
            name = mac.computerName;
            info = '$name / macOS ${mac.osRelease}';
            break;
          case TargetPlatform.windows:
            final win = await plugin.windowsInfo;
            name = win.computerName;
            info = '$name / Windows';
            break;
          case TargetPlatform.linux:
            final linux = await plugin.linuxInfo;
            name = linux.prettyName;
            info = '$name / Linux';
            break;
          case TargetPlatform.fuchsia:
            name = 'Fuchsia';
            info = 'Fuchsia';
            break;
        }
      }
    } catch (e) {
      debugPrint('[DeviceInfo] gagal membaca info perangkat: $e');
    }

    _deviceName = name.trim().isEmpty ? 'Perangkat' : name.trim();
    _deviceInfo = info.trim().isEmpty ? _deviceName : info.trim();
  }
}
