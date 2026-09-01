import 'package:flutter/material.dart';

import 'package:flutter_absensi_app/core/assets/assets.gen.dart';
import 'package:flutter_absensi_app/core/config/app_config.dart';

/// Logo aplikasi dari `/api/app-settings`.
///
/// Admin bisa mengganti logo tanpa rilis baru; bila `logo_url` kosong atau
/// gagal dimuat, aset bawaan aplikasi dipakai supaya layar tidak pernah
/// tampil tanpa identitas.
class AppLogo extends StatelessWidget {
  final double size;

  /// Pakai varian terang untuk latar gelap (splash, banner login).
  final bool light;

  const AppLogo({super.key, this.size = 90, this.light = false});

  @override
  Widget build(BuildContext context) {
    final settings = AppConfig.value;
    final url = light
        ? (settings.logoDarkUrl ?? settings.logoUrl)
        : (settings.logoUrl ?? settings.logoDarkUrl);

    final fallback = Image.asset(
      light ? Assets.images.logoWhite.path : Assets.images.logoGeoSquare.path,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (url == null || url.isEmpty) return fallback;

    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}
