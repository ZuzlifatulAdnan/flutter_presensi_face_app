import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_absensi_app/core/theme/app_theme.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_precheck_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_summary_model.dart';
import 'package:flutter_absensi_app/presentation/history/blocs/attendance_summary/attendance_summary_bloc.dart';

/// Kartu rekap bulanan dari `GET /api/attendance/summary`.
///
/// Angka dihitung server (termasuk pengecualian akhir pekan dan hari libur),
/// jadi aplikasi hanya menampilkannya.
class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceSummaryBloc, AttendanceSummaryState>(
      builder: (context, state) => state.maybeWhen(
        loading: () => const _SummarySkeleton(),
        loaded: (summary) => _SummaryContent(summary: summary),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  final AttendanceSummary summary;

  const _SummaryContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded,
                    size: 18, color: AppTheme.info),
                const SizedBox(width: 8),
                const Text(
                  'Rekap Bulan Ini',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(summary.onTimeRatio * 100).round()}% tepat waktu',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                  label: 'Hadir',
                  value: '${summary.totalPresent}',
                  color: AppTheme.info,
                  icon: Icons.event_available_rounded,
                ),
                _Stat(
                  label: 'Tepat Waktu',
                  value: '${summary.onTime}',
                  color: AppTheme.success,
                  icon: Icons.check_circle_rounded,
                ),
                _Stat(
                  label: 'Terlambat',
                  value: '${summary.late}',
                  color: AppTheme.warning,
                  icon: Icons.schedule_rounded,
                ),
                _Stat(
                  label: 'Cuti',
                  value: '${summary.approvedLeaveDays}',
                  color: AppTheme.textSecondary,
                  icon: Icons.beach_access_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                  label: 'Jam kerja',
                  value: summary.workDurationLabel,
                ),
                if (summary.lateMinutes > 0)
                  _Pill(
                    label: 'Total terlambat',
                    value: summary.lateDurationLabel,
                    color: AppTheme.warning,
                  ),
                for (final mode in WorkMode.values)
                  if (summary.countFor(mode) > 0)
                    _Pill(
                      label: mode.label,
                      value: '${summary.countFor(mode)} hari',
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Pill({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontSize: 11.5, color: tone),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: 150,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
