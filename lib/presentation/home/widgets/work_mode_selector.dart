import 'package:flutter/material.dart';

import 'package:flutter_absensi_app/core/theme/app_theme.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_precheck_model.dart';

/// Pilihan mode kerja untuk presensi.
///
/// Daftar pilihan selalu berasal dari `work_mode.allowed` pada `pre-check`,
/// bukan ditebak dari profil pengguna — server tetap memvalidasi ulang.
class WorkModeSelector extends StatelessWidget {
  final List<WorkMode> modes;
  final WorkMode selected;
  final ValueChanged<WorkMode> onChanged;

  const WorkModeSelector({
    super.key,
    required this.modes,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        for (final mode in modes)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: mode == modes.last ? 0 : 8,
              ),
              child: _ModeTile(
                mode: mode,
                selected: mode == selected,
                color: primary,
                onTap: () => onChanged(mode),
              ),
            ),
          ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  final WorkMode mode;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  IconData get _icon => switch (mode) {
        WorkMode.wfo => Icons.business_rounded,
        WorkMode.wfh => Icons.home_work_rounded,
        WorkMode.wfa => Icons.travel_explore_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected ? color : AppTheme.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _icon,
              size: 22,
              color: selected ? color : AppTheme.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              mode.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              mode.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.25,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
