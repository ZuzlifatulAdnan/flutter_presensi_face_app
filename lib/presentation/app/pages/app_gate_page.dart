import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_absensi_app/core/config/app_config.dart';
import 'package:flutter_absensi_app/core/theme/app_theme.dart';
import 'package:flutter_absensi_app/data/models/response/app_settings_model.dart';

/// Layar penghalang: pemeliharaan server atau wajib perbarui aplikasi.
///
/// Keduanya berbagi kerangka yang sama karena sama-sama menghentikan alur
/// aplikasi dan hanya menyisakan satu tindakan bagi pengguna.
class AppGatePage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onRetry;

  const AppGatePage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onRetry,
  });

  /// Mode pemeliharaan aktif (`maintenance.enabled`).
  factory AppGatePage.maintenance({
    required AppMaintenanceSettings settings,
    VoidCallback? onRetry,
  }) =>
      AppGatePage(
        icon: Icons.construction_rounded,
        title: 'Sedang Dalam Pemeliharaan',
        message: settings.message?.trim().isNotEmpty == true
            ? settings.message!
            : 'Aplikasi sedang dalam pemeliharaan. Silakan coba beberapa '
                'saat lagi.',
        onRetry: onRetry,
      );

  /// Versi terpasang di bawah `version.android_minimum` / `ios_minimum`
  /// dengan `force_update` menyala.
  factory AppGatePage.forceUpdate({
    required AppVersionSettings version,
    required String installedVersion,
    VoidCallback? onRetry,
  }) {
    final latest = version.androidLatest ?? version.iosLatest;
    return AppGatePage(
      icon: Icons.system_update_rounded,
      title: 'Perbarui Aplikasi',
      message: 'Versi aplikasi Anda ($installedVersion) sudah tidak '
          'didukung.${latest == null ? '' : ' Versi terbaru adalah $latest.'} '
          'Perbarui aplikasi untuk melanjutkan presensi.',
      actionLabel: 'Buka Halaman Pembaruan',
      onAction: _openStore,
      onRetry: onRetry,
    );
  }

  static Future<void> _openStore() async {
    // Tautan pembaruan mengikuti applicationId rilis di Play Store.
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.jagoflutter.hris',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final company = AppConfig.value.company;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                if (actionLabel != null && onAction != null)
                  FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                if (onRetry != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Periksa Lagi'),
                  ),
                ],
                if (company.supportEmail != null ||
                    company.supportPhone != null) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Butuh bantuan? Hubungi '
                    '${company.supportEmail ?? company.supportPhone}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
