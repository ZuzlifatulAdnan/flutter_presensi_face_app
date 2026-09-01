import 'dart:convert';

import 'package:flutter/material.dart';

/// Pengaturan aplikasi dari `GET /api/app-settings`.
///
/// Objek yang sama juga ikut pada `data.app` di respons `/api/login` dan
/// `/api/me`, jadi setelah login tidak perlu request terpisah.
class AppSettingsModel {
  final String appName;
  final String appShortName;
  final String? tagline;
  final String? logoUrl;
  final String? logoDarkUrl;
  final String? faviconUrl;
  final String? loginBannerUrl;
  final AppThemeSettings theme;
  final AppCompanySettings company;
  final AppVersionSettings version;
  final AppMaintenanceSettings maintenance;
  final AttendanceSettings attendance;
  final MapSettings map;
  final DateTime? updatedAt;

  const AppSettingsModel({
    required this.appName,
    required this.appShortName,
    this.tagline,
    this.logoUrl,
    this.logoDarkUrl,
    this.faviconUrl,
    this.loginBannerUrl,
    this.theme = const AppThemeSettings(),
    this.company = const AppCompanySettings(),
    this.version = const AppVersionSettings(),
    this.maintenance = const AppMaintenanceSettings(),
    this.attendance = const AttendanceSettings(),
    this.map = const MapSettings(),
    this.updatedAt,
  });

  /// Nilai bawaan saat API belum sempat dihubungi (mis. splash offline).
  static const AppSettingsModel fallback = AppSettingsModel(
    appName: 'Absen Devtech KI',
    appShortName: 'AbsenDav',
    tagline: 'Presensi cepat, akurat, dan transparan',
  );

  factory AppSettingsModel.fromJson(String str) =>
      AppSettingsModel.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory AppSettingsModel.fromMap(Map<String, dynamic> json) =>
      AppSettingsModel(
        appName: json['app_name']?.toString() ?? fallback.appName,
        appShortName:
            json['app_short_name']?.toString() ?? fallback.appShortName,
        tagline: json['tagline']?.toString(),
        logoUrl: json['logo_url']?.toString(),
        logoDarkUrl: json['logo_dark_url']?.toString(),
        faviconUrl: json['favicon_url']?.toString(),
        loginBannerUrl: json['login_banner_url']?.toString(),
        theme: AppThemeSettings.fromMap(_map(json['theme'])),
        company: AppCompanySettings.fromMap(_map(json['company'])),
        version: AppVersionSettings.fromMap(_map(json['version'])),
        maintenance: AppMaintenanceSettings.fromMap(_map(json['maintenance'])),
        attendance: AttendanceSettings.fromMap(_map(json['attendance'])),
        map: MapSettings.fromMap(_map(json['map'])),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.tryParse(json['updated_at'].toString()),
      );

  Map<String, dynamic> toMap() => {
        'app_name': appName,
        'app_short_name': appShortName,
        'tagline': tagline,
        'logo_url': logoUrl,
        'logo_dark_url': logoDarkUrl,
        'favicon_url': faviconUrl,
        'login_banner_url': loginBannerUrl,
        'theme': theme.toMap(),
        'company': company.toMap(),
        'version': version.toMap(),
        'maintenance': maintenance.toMap(),
        'attendance': attendance.toMap(),
        'map': map.toMap(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
}

class AppThemeSettings {
  final String? primaryColor;
  final String? secondaryColor;

  const AppThemeSettings({this.primaryColor, this.secondaryColor});

  factory AppThemeSettings.fromMap(Map<String, dynamic> json) =>
      AppThemeSettings(
        primaryColor: json['primary_color']?.toString(),
        secondaryColor: json['secondary_color']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'primary_color': primaryColor,
        'secondary_color': secondaryColor,
      };

  Color? get primary => parseHex(primaryColor);

  Color? get secondary => parseHex(secondaryColor);

  /// Terima `#RRGGBB`, `#AARRGGBB`, atau tanpa tanda pagar.
  static Color? parseHex(String? hex) {
    if (hex == null) return null;
    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'ff$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}

class AppCompanySettings {
  final String? name;
  final String? address;
  final String? supportEmail;
  final String? supportPhone;
  final String? website;

  const AppCompanySettings({
    this.name,
    this.address,
    this.supportEmail,
    this.supportPhone,
    this.website,
  });

  factory AppCompanySettings.fromMap(Map<String, dynamic> json) =>
      AppCompanySettings(
        name: json['name']?.toString(),
        address: json['address']?.toString(),
        supportEmail: json['support_email']?.toString(),
        supportPhone: json['support_phone']?.toString(),
        website: json['website']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'support_email': supportEmail,
        'support_phone': supportPhone,
        'website': website,
      };
}

class AppVersionSettings {
  final String? androidLatest;
  final String? androidMinimum;
  final String? iosLatest;
  final String? iosMinimum;
  final bool forceUpdate;

  const AppVersionSettings({
    this.androidLatest,
    this.androidMinimum,
    this.iosLatest,
    this.iosMinimum,
    this.forceUpdate = false,
  });

  factory AppVersionSettings.fromMap(Map<String, dynamic> json) =>
      AppVersionSettings(
        androidLatest: json['android_latest']?.toString(),
        androidMinimum: json['android_minimum']?.toString(),
        iosLatest: json['ios_latest']?.toString(),
        iosMinimum: json['ios_minimum']?.toString(),
        forceUpdate: json['force_update'] == true,
      );

  Map<String, dynamic> toMap() => {
        'android_latest': androidLatest,
        'android_minimum': androidMinimum,
        'ios_latest': iosLatest,
        'ios_minimum': iosMinimum,
        'force_update': forceUpdate,
      };

  /// Bandingkan versi semantik `a` dan `b`.
  /// Mengembalikan < 0 bila a lebih lama, 0 bila sama, > 0 bila a lebih baru.
  ///
  /// Build number dan pra-rilis (`1.4.0+5`, `1.4.0-beta`) diabaikan: yang
  /// menentukan wajib-update hanyalah versi rilisnya. Tanpa ini `1.4.0+5`
  /// terbaca lebih baru dari `1.4.0` dan aplikasi bisa melewatkan pembaruan
  /// wajib.
  static int compare(String a, String b) {
    List<int> parts(String v) => v
        .split(RegExp(r'[+-]'))
        .first
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();

    final left = parts(a);
    final right = parts(b);
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l - r;
    }
    return 0;
  }
}

class AppMaintenanceSettings {
  final bool enabled;
  final String? message;

  const AppMaintenanceSettings({this.enabled = false, this.message});

  factory AppMaintenanceSettings.fromMap(Map<String, dynamic> json) =>
      AppMaintenanceSettings(
        enabled: json['enabled'] == true,
        message: json['message']?.toString(),
      );

  Map<String, dynamic> toMap() => {'enabled': enabled, 'message': message};
}

/// Aturan presensi yang menentukan field mana yang wajib di UI.
class AttendanceSettings {
  final bool photoRequired;
  final bool wfhEnabled;
  final bool wfhPhotoRequired;
  final bool wfhNotesRequired;
  final bool blockMockLocation;
  final double accuracyToleranceMeters;

  const AttendanceSettings({
    this.photoRequired = false,
    this.wfhEnabled = false,
    this.wfhPhotoRequired = true,
    this.wfhNotesRequired = true,
    this.blockMockLocation = true,
    this.accuracyToleranceMeters = 50,
  });

  factory AttendanceSettings.fromMap(Map<String, dynamic> json) =>
      AttendanceSettings(
        photoRequired: json['photo_required'] == true,
        wfhEnabled: json['wfh_enabled'] == true,
        wfhPhotoRequired: json['wfh_photo_required'] != false,
        wfhNotesRequired: json['wfh_notes_required'] != false,
        blockMockLocation: json['block_mock_location'] != false,
        accuracyToleranceMeters:
            (json['accuracy_tolerance_meters'] as num?)?.toDouble() ?? 50,
      );

  Map<String, dynamic> toMap() => {
        'photo_required': photoRequired,
        'wfh_enabled': wfhEnabled,
        'wfh_photo_required': wfhPhotoRequired,
        'wfh_notes_required': wfhNotesRequired,
        'block_mock_location': blockMockLocation,
        'accuracy_tolerance_meters': accuracyToleranceMeters,
      };
}

class MapSettings {
  final double defaultZoom;
  final String tileUrl;
  final String attribution;

  const MapSettings({
    this.defaultZoom = 17,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.attribution = 'OpenStreetMap contributors',
  });

  factory MapSettings.fromMap(Map<String, dynamic> json) => MapSettings(
        defaultZoom: (json['default_zoom'] as num?)?.toDouble() ?? 17,
        tileUrl: json['tile_url']?.toString() ??
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        attribution:
            json['attribution']?.toString() ?? 'OpenStreetMap contributors',
      );

  Map<String, dynamic> toMap() => {
        'default_zoom': defaultZoom,
        'tile_url': tileUrl,
        'attribution': attribution,
      };
}
