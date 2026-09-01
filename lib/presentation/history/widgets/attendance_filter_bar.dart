import 'package:flutter/material.dart';

import 'package:flutter_absensi_app/core/theme/app_theme.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_precheck_model.dart';

/// Filter riwayat presensi yang dikirim ke server sebagai query string.
class AttendanceFilter {
  final DateTime? date;
  final String? status;
  final WorkMode? workMode;

  const AttendanceFilter({this.date, this.status, this.workMode});

  bool get isEmpty => date == null && status == null && workMode == null;

  AttendanceFilter copyWith({
    DateTime? date,
    String? status,
    WorkMode? workMode,
    bool clearDate = false,
    bool clearStatus = false,
    bool clearWorkMode = false,
  }) =>
      AttendanceFilter(
        date: clearDate ? null : (date ?? this.date),
        status: clearStatus ? null : (status ?? this.status),
        workMode: clearWorkMode ? null : (workMode ?? this.workMode),
      );

  /// Format `YYYY-MM-DD` yang diterima endpoint riwayat.
  String? get dateParam => date == null
      ? null
      : '${date!.year.toString().padLeft(4, '0')}-'
          '${date!.month.toString().padLeft(2, '0')}-'
          '${date!.day.toString().padLeft(2, '0')}';
}

/// Baris chip filter: status kehadiran dan mode kerja.
class AttendanceFilterBar extends StatelessWidget {
  final AttendanceFilter filter;
  final ValueChanged<AttendanceFilter> onChanged;

  const AttendanceFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  static const Map<String, String> _statuses = {
    'on_time': 'Tepat Waktu',
    'late': 'Terlambat',
    'absent': 'Tidak Hadir',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final entry in _statuses.entries)
            _Chip(
              label: entry.value,
              selected: filter.status == entry.key,
              onTap: () => onChanged(
                filter.status == entry.key
                    ? filter.copyWith(clearStatus: true)
                    : filter.copyWith(status: entry.key),
              ),
            ),
          const _Separator(),
          for (final mode in WorkMode.values)
            _Chip(
              label: mode.label,
              selected: filter.workMode == mode,
              onTap: () => onChanged(
                filter.workMode == mode
                    ? filter.copyWith(clearWorkMode: true)
                    : filter.copyWith(workMode: mode),
              ),
            ),
          if (!filter.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: TextButton.icon(
                onPressed: () => onChanged(const AttendanceFilter()),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Reset'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: primary.withValues(alpha: 0.12),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? primary : AppTheme.textPrimary,
        ),
        side: BorderSide(color: selected ? primary : AppTheme.outline),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(right: 8),
        child: SizedBox(
          height: 22,
          child: VerticalDivider(width: 1, color: AppTheme.outline),
        ),
      );
}
