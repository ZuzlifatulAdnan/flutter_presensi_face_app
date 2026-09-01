import 'package:flutter/material.dart';

import 'package:flutter_absensi_app/core/theme/app_theme.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_response_model.dart';
import 'package:flutter_absensi_app/presentation/leaves/pages/attachment_viewer_page.dart';

/// Bukti presensi yang kini dikirim server: foto, catatan aktivitas, alamat,
/// jarak dari kantor, mode kerja, durasi kerja, dan indikator fake GPS.
class AttendanceEvidenceCard extends StatelessWidget {
  final Attendance attendance;

  const AttendanceEvidenceCard({super.key, required this.attendance});

  @override
  Widget build(BuildContext context) {
    final checkIn = attendance.checkIn;
    final checkOut = attendance.checkOut;

    final hasEvidence = (checkIn != null && !checkIn.isEmpty) ||
        (checkOut != null && !checkOut.isEmpty) ||
        attendance.workMode != null ||
        attendance.workDurationMinutes != null;

    if (!hasEvidence) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_rounded,
                    size: 18, color: AppTheme.info),
                const SizedBox(width: 8),
                const Text(
                  'Bukti Presensi',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _Badge(
                  label: attendance.displayWorkMode,
                  color: attendance.isRemoteMode
                      ? AppTheme.warning
                      : AppTheme.info,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (attendance.isMockLocation == true)
              const _Warning(
                message: 'Presensi ini terindikasi memakai lokasi palsu '
                    '(fake GPS).',
              ),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (attendance.workDurationMinutes != null)
                  _Badge(
                    label: 'Durasi ${attendance.workDurationLabel}',
                    color: AppTheme.success,
                  ),
                if ((attendance.lateMinutes ?? 0) > 0)
                  _Badge(
                    label: 'Terlambat ${attendance.lateMinutes} menit',
                    color: AppTheme.warning,
                  ),
                if ((attendance.earlyLeaveMinutes ?? 0) > 0)
                  _Badge(
                    label: 'Pulang cepat ${attendance.earlyLeaveMinutes} menit',
                    color: AppTheme.warning,
                  ),
                if (attendance.isHoliday == true)
                  const _Badge(label: 'Hari libur', color: AppTheme.info),
              ],
            ),

            if (checkIn != null && !checkIn.isEmpty) ...[
              const SizedBox(height: 14),
              _LegSection(
                title: 'Absen Masuk',
                time: attendance.timeIn,
                leg: checkIn,
                color: AppTheme.success,
              ),
            ],
            if (checkOut != null && !checkOut.isEmpty) ...[
              const SizedBox(height: 14),
              _LegSection(
                title: 'Absen Pulang',
                time: attendance.timeOut,
                leg: checkOut,
                color: AppTheme.info,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegSection extends StatelessWidget {
  final String title;
  final String? time;
  final AttendanceLeg leg;
  final Color color;

  const _LegSection({
    required this.title,
    required this.time,
    required this.leg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              if (time != null)
                Text(
                  time!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (leg.hasPhoto) ...[
            const SizedBox(height: 10),
            _PhotoThumb(url: leg.photoUrl!),
          ],
          if (leg.address != null && leg.address!.isNotEmpty)
            _Detail(icon: Icons.place_outlined, text: leg.address!),
          if (leg.distanceMeters != null)
            _Detail(
              icon: Icons.social_distance_rounded,
              text: 'Jarak dari kantor: ${_distanceLabel(leg.distanceMeters!)}',
            ),
          if (leg.notes != null && leg.notes!.isNotEmpty)
            _Detail(icon: Icons.notes_rounded, text: leg.notes!),
        ],
      ),
    );
  }

  static String _distanceLabel(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

class _PhotoThumb extends StatelessWidget {
  final String url;

  const _PhotoThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttachmentViewerPage(attachmentUrl: url),
        ),
      ),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Image.network(
          url,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 140,
            alignment: Alignment.center,
            color: AppTheme.surface,
            child: const Text(
              'Foto tidak dapat dimuat',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Detail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  final String message;

  const _Warning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.gpp_bad_rounded, size: 18, color: AppTheme.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.danger,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
