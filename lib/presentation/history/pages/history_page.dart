import 'package:flutter/material.dart';
import 'package:flutter_absensi_app/presentation/history/blocs/get_all_attendances/get_all_attendances_bloc.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_response_model.dart';
import 'package:flutter_absensi_app/presentation/history/pages/detail_history_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/core.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context
          .read<GetAllAttendancesBloc>()
          .add(const GetAllAttendancesEvent.getAllAttendances());
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1e3c72),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3, 1.0],
            colors: [
              Color(0xFF1e3c72),
              Color(0xFF2a5298),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: BlocBuilder<GetAllAttendancesBloc,
                    GetAllAttendancesState>(
                  builder: (context, state) {
                    return state.maybeWhen(
                      orElse: () => _buildEmptyState(),
                      loading: () => _buildLoadingState(),
                      empty: () => _buildNoDataState(),
                      error: (message) => _buildErrorState(message),
                      loaded: (attendances) =>
                          _buildAttendanceList(attendances),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riwayat Kehadiran',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _selectedDate != null
                      ? DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate!)
                      : 'Lacak catatan kehadiran harian Anda',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedDate != null) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.clear_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _clearDateFilter,
                tooltip: 'Clear filter',
              ),
            ),
            const SpaceWidth(8),
          ],
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => _selectDate(context),
              tooltip: 'Pilih tanggal',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    context
        .read<GetAllAttendancesBloc>()
        .add(const GetAllAttendancesEvent.getAllAttendances());
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF1e3c72),
                    size: 48,
                  ),
                ),
                const SpaceHeight(16),
                Text(
                  'Pilih Tanggal',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SpaceHeight(8),
                Text(
                  'Tidak ada data kehadiran yang tersedia',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataState() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.event_busy_rounded,
                    color: Colors.orange,
                    size: 48,
                  ),
                ),
                const SpaceHeight(16),
                Text(
                  'Tidak ada catatan kehadiran',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SpaceHeight(8),
                Text(
                  'Anda belum memiliki riwayat kehadiran.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataForSelectedDateState() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.blue,
                    size: 48,
                  ),
                ),
                const SpaceHeight(16),
                Text(
                  'Tidak ada data untuk tanggal ini',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SpaceHeight(8),
                Text(
                  'Tidak ditemukan catatan kehadiran untuk ${DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate!)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                const SpaceHeight(16),
                Text(
                  'Kesalahan Memuat Data',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SpaceHeight(8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    message,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceList(List<Attendance> attendances) {
    var filteredAttendances = List<Attendance>.from(attendances);

    // Filter by selected date if any
    if (_selectedDate != null) {
      filteredAttendances = filteredAttendances.where((attendance) {
        if (attendance.date == null) return false;
        return attendance.date!.year == _selectedDate!.year &&
            attendance.date!.month == _selectedDate!.month &&
            attendance.date!.day == _selectedDate!.day;
      }).toList();

      if (filteredAttendances.isEmpty) {
        return _buildNoDataForSelectedDateState();
      }
    }

    if (filteredAttendances.isEmpty) {
      return _buildNoDataState();
    }

    // Sort by date descending (newest first)
    filteredAttendances.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });

    return RefreshIndicator(
      color: const Color(0xFF1e3c72),
      onRefresh: () async {
        context
            .read<GetAllAttendancesBloc>()
            .add(const GetAllAttendancesEvent.getAllAttendances());
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: filteredAttendances.length,
        separatorBuilder: (context, index) => const SpaceHeight(16),
        itemBuilder: (context, index) {
          final attendance = filteredAttendances[index];
          return _buildAttendanceCard(attendance);
        },
      ),
    );
  }

  Widget _buildAttendanceCard(Attendance attendance) {
    final dateFormatter = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    final timeFormatter = DateFormat('HH:mm');
    final statusColor = _getStatusColor(attendance.status);
    final statusLabel = _getStatusLabel(attendance.status);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailHistoryPage(attendance: attendance),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with date and status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getStatusIcon(attendance.status),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SpaceWidth(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormatter.format(attendance.date ?? DateTime.now()),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    const SpaceHeight(4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: statusColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (attendance.isWeekend == true) ...[
                          const SpaceWidth(8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Weekend',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        ],
                        if (attendance.isHoliday == true) ...[
                          const SpaceWidth(8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Holiday',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SpaceHeight(16),
          const Divider(height: 1),
          const SpaceHeight(16),

          // Check In/Out Times
          Row(
            children: [
              Expanded(
                child: _buildTimeInfo(
                  'Masuk',
                  attendance.timeIn ?? '-',
                  Icons.login_rounded,
                  AppColors.green,
                ),
              ),
              const SpaceWidth(16),
              Expanded(
                child: _buildTimeInfo(
                  'Pulang',
                  attendance.timeOut ?? '-',
                  Icons.logout_rounded,
                  AppColors.red,
                ),
              ),
            ],
          ),
          if ((attendance.workMode ?? '').trim().isNotEmpty) ...[
            const SpaceHeight(12),
            _buildMetaInfo(
              'Mode Kerja',
              _formatWorkMode(attendance.workMode),
              Icons.work_outline_rounded,
              Colors.indigo,
            ),
          ],

          // Late/Early Leave Info
          if ((attendance.lateMinutes ?? 0) > 0 ||
              (attendance.earlyLeaveMinutes ?? 0) > 0) ...[
            const SpaceHeight(12),
            Row(
              children: [
                if ((attendance.lateMinutes ?? 0) > 0)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SpaceWidth(8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Telat',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.red.withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  '${attendance.lateMinutes} min',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if ((attendance.lateMinutes ?? 0) > 0 &&
                    (attendance.earlyLeaveMinutes ?? 0) > 0)
                  const SpaceWidth(12),
                if ((attendance.earlyLeaveMinutes ?? 0) > 0)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timelapse_rounded,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SpaceWidth(8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Early Leave',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.orange.withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  '${attendance.earlyLeaveMinutes} min',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildTimeInfo(
      String label, String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SpaceWidth(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: color.withOpacity(0.7),
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SpaceWidth(10),
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: color.withOpacity(0.7),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatWorkMode(String? value) {
    final rawValue = value?.trim();
    if (rawValue == null || rawValue.isEmpty) return '-';

    switch (rawValue.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_')) {
      case 'wfo':
      case 'office':
      case 'work_from_office':
        return 'WFO';
      case 'wfh':
      case 'remote':
      case 'work_from_home':
        return 'WFH';
      case 'hybrid':
        return 'Hybrid';
      default:
        return rawValue
            .split(RegExp(r'[_\s-]+'))
            .where((word) => word.isNotEmpty)
            .map((word) => word.length == 1
                ? word.toUpperCase()
                : '${word[0].toUpperCase()}${word.substring(1)}')
            .join(' ');
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'Tepat Waktu':
        return AppColors.green;
      case 'Telat':
        return Colors.orange;
      case 'Absen':
        return AppColors.red;
      default:
        return AppColors.primary;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'tepat_waktu':
        return 'Tepat Waktu';
      case 'telat':
        return 'Telat';
      case 'absen':
        return 'Absen';
      default:
        return status ?? 'Tidak dikenal';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'tepat_waktu':
        return Icons.check_circle_rounded;
      case 'telat':
        return Icons.access_time_rounded;
      case 'absen':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
