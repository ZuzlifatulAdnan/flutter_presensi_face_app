
import 'package:flutter/material.dart';
import 'package:flutter_absensi_app/core/constants/variables.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_absensi_app/data/models/response/auth_response_model.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/get_company/get_company_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/is_checkedin/is_checkedin_bloc.dart';
import 'package:flutter_absensi_app/core/ml/face_engine_provider.dart';
import 'package:flutter_absensi_app/presentation/home/pages/attandences/attendance_page.dart';
import 'package:flutter_absensi_app/presentation/leaves/pages/leave_page.dart';
import 'package:flutter_absensi_app/presentation/overtimes/pages/overtime_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_absensi_app/core/helper/location_helper.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/core.dart';
import '../../profile/bloc/get_user/get_user_bloc.dart';
import 'register_face_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String? faceEmbedding;

  /// Mode kerja pengguna menentukan apakah menu WFH/WFA ditampilkan.
  /// Server tetap memvalidasi ulang lewat `pre-check` saat menu dibuka.
  bool _remoteAllowed = false;
  double? latitude;
  double? longitude;
  String? _currentLocationAddress;


  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _cardController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _cardAnimation;

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _initializeFaceEmbedding();

    context.read<IsCheckedinBloc>().add(const IsCheckedinEvent.isCheckedIn());
    context.read<GetCompanyBloc>().add(const GetCompanyEvent.getCompany());
    context.read<GetUserBloc>().add(const GetUserEvent.getUser());

    getCurrentPosition();
    _loadRemoteAvailability();
    _startAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _cardAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _fadeController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _slideController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        _cardController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> getCurrentPosition() async {
    final position = await LocationHelper.tryCurrent();
    if (position == null || !mounted) return;

    latitude = position.latitude;
    longitude = position.longitude;
    setState(() {});

    // Reverse geocoding dijalankan setelah koordinat tampil supaya kartu
    // lokasi tidak menunggu request jaringan tambahan.
    final address = await LocationHelper.addressOf(
      position.latitude,
      position.longitude,
    );
    if (!mounted) return;
    setState(() => _currentLocationAddress = address);
  }

  /// WFH/WFA hanya relevan bila admin memberi pengguna mode kerja jarak jauh
  /// (`users.work_mode` bernilai `wfh` atau `wfa`).
  Future<void> _loadRemoteAvailability() async {
    final authData = await AuthLocalDatasource().getAuthData();
    final mode = (authData?.user?.workMode ?? authData?.workMode ?? 'wfo')
        .toLowerCase()
        .replaceAll('-', '_');
    if (!mounted) return;
    setState(() => _remoteAllowed = mode == 'wfh' || mode == 'wfa');
  }

  Future<void> _initializeFaceEmbedding() async {
    try {
      final authData = await AuthLocalDatasource().getAuthData();
      setState(() {
        faceEmbedding = authData?.user?.faceEmbedding;
      });
    } catch (e) {
      debugPrint('Error fetching auth data: $e');
      setState(() {
        faceEmbedding = null;
      });
    }
  }


  Future<void> _onRefresh() async {
    // Refresh all data
    context.read<GetUserBloc>().add(const GetUserEvent.getUser());
    context.read<GetCompanyBloc>().add(const GetCompanyEvent.getCompany());
    context.read<IsCheckedinBloc>().add(const IsCheckedinEvent.isCheckedIn());

    // Refresh face embedding
    await _initializeFaceEmbedding();
    await _loadRemoteAvailability();
    await getCurrentPosition();

    // Wait a bit for the blocs to process
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {});
    }
  }

  String _formatShiftTime(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) return fallback;

    final rawValue = value.trim();
    final parsedDate = DateTime.tryParse(rawValue);
    if (parsedDate != null) {
      final localDate = parsedDate.toLocal();
      return '${localDate.hour.toString().padLeft(2, '0')}:'
          '${localDate.minute.toString().padLeft(2, '0')}';
    }

    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(rawValue);
    if (timeMatch != null) {
      final hour = timeMatch.group(1)!.padLeft(2, '0');
      final minute = timeMatch.group(2)!;
      return '$hour:$minute';
    }

    return fallback;
  }

  String _formatRole(String? value) {
    final raw = value?.trim().toLowerCase() ?? '';
    switch (raw) {
      case 'employee':
      case 'karyawan':
        return 'Karyawan';
      case 'admin':
        return 'Admin';
      case 'manager':
      case 'manajer':
        return 'Manajer';
      case 'supervisor':
        return 'Supervisor';
      case 'director':
      case 'direktur':
        return 'Direktur';
      case 'staff':
        return 'Staf';
      default:
        if (raw.isEmpty) return '-';
        return '${raw[0].toUpperCase()}${raw.substring(1)}';
    }
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

  String _formatAttendanceLocation(String? address) {
    final trimmedAddress = address?.trim();
    if (trimmedAddress != null && trimmedAddress.isNotEmpty) {
      return trimmedAddress;
    }

    if (_currentLocationAddress != null && _currentLocationAddress!.isNotEmpty) {
      return _currentLocationAddress!;
    }

    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(6)}, '
          '${longitude!.toStringAsFixed(6)}';
    }

    return 'Belum tersedia';
  }

  /// Membangun URL penuh foto profil.
  /// Backend mengembalikan path relatif (misal "images/photo.jpg"),
  /// perlu ditambahkan baseUrl + "/storage/" di depannya.
  String? _buildFullImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final url = rawUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final clean = url.startsWith('/') ? url.substring(1) : url;
    return '${Variables.baseUrl}/storage/$clean';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4, 1.0],
            colors: [
              Color(0xFF1e3c72), // Deep professional blue
              Color(0xFF2a5298), // Professional blue
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: const Color(0xFF1e3c72),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Header Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16.0),
                      child: _buildHeader(),
                    ),
                  ),

                  const SpaceHeight(10),

                  // Time Card Section
                  SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _cardAnimation,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildTimeCard(),
                      ),
                    ),
                  ),

                  const SpaceHeight(32),

                  // Menu Grid Section
                  SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _buildMenuGrid(),
                    ),
                  ),

                  const SpaceHeight(24),

                  // // Face Attendance Button
                  // if (faceEmbedding != null)
                  //   ScaleTransition(
                  //     scale: _cardAnimation,
                  //     child: Container(
                  //       margin: const EdgeInsets.symmetric(horizontal: 24.0),
                  //       child: _buildFaceAttendanceButton(),
                  //     ),
                  //   ),

                  // const SpaceHeight(24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FutureBuilder<AuthResponseModel?>(
      future: AuthLocalDatasource().getAuthData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingHeader();
        }

        final authData = snapshot.data;

        return BlocBuilder<GetUserBloc, GetUserState>(
          builder: (context, userState) {
            final freshUser = userState.maybeWhen(
              success: (u) => u,
              orElse: () => null,
            );

            final authUser = authData?.user;
            // Nama: authData (login) pasti punya nama lengkap, freshUser mungkin tidak
            final userName = authUser?.name ?? freshUser?.name ?? 'Pengguna';
            final imageUrl = _buildFullImageUrl(
                (freshUser?.imageUrl ?? authUser?.imageUrl)?.toString());

            // Prioritize login response (authData) for relational fields
            final role = _formatRole(authData?.role ?? freshUser?.role ?? authUser?.role);
            final position = authData?.position?.name ??
                freshUser?.position ??
                authUser?.position ?? '-';
            final departmentName = authData?.department?.name ??
                freshUser?.departemen?.name ??
                freshUser?.department ??
                authUser?.departemen?.name ??
                authUser?.department ?? '-';
            final shiftName = authData?.defaultShift?.name ??
                freshUser?.shiftKerja?.name ??
                authUser?.shiftKerja?.name ?? '-';

            return BlocBuilder<GetCompanyBloc, GetCompanyState>(
              builder: (context, companyState) {
                final officeLocation = companyState.maybeWhen(
                  success: (company) =>
                      (company.name != null && company.name!.isNotEmpty)
                          ? company.name!
                          : (authData?.company?.name ?? '-'),
                  orElse: () => authData?.company?.name ?? '-',
                );

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _buildAvatarPlaceholder(),
                                    )
                                  : _buildAvatarPlaceholder(),
                            ),
                          ),
                          const SpaceWidth(16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, $userName',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SpaceHeight(2),
                                Text(
                                  position,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SpaceHeight(12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildHeaderInfoRow(
                              Icons.badge_rounded,
                              'Peran: $role',
                            ),
                            const SpaceHeight(6),
                            _buildHeaderInfoRow(
                              Icons.business_rounded,
                              'Departemen: $departmentName',
                            ),
                            const SpaceHeight(6),
                            _buildHeaderInfoRow(
                              Icons.access_time_rounded,
                              'Shift: $shiftName',
                            ),
                            const SpaceHeight(6),
                            _buildHeaderInfoRow(
                              Icons.location_city_rounded,
                              'Kantor: $officeLocation',
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(25),
      ),
      child: const Icon(Icons.person, size: 28, color: Colors.white),
    );
  }

  Widget _buildHeaderInfoRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
        const SpaceWidth(8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
          const SpaceWidth(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SpaceHeight(8),
                Container(
                  height: 14,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return FutureBuilder(
      future: AuthLocalDatasource().getAuthData(),
      builder: (context, snapshot) {
        String startTime = '08:00';
        String endTime = '17:00';
        String workMode = '-';
        String? attendanceAddress;

        if (snapshot.hasData && snapshot.data != null) {
          final authData = snapshot.data!;
          final rawStart = authData.user?.shiftKerja?.startTime ??
              authData.defaultShiftDetail?.startTime;
          final rawEnd = authData.user?.shiftKerja?.endTime ??
              authData.defaultShiftDetail?.endTime;
          startTime = _formatShiftTime(rawStart, '08:00');
          endTime = _formatShiftTime(rawEnd, '17:00');
          workMode =
              _formatWorkMode(authData.user?.workMode ?? authData.workMode);
          attendanceAddress = authData.company?.address;
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1e3c72), Color(0xFF3b82c9)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
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
                          'Waktu Saat Ini',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          DateTime.now().toFormattedDate(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SpaceHeight(20),
              Text(
                DateTime.now().toFormattedTime(),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 36,
                  color: const Color(0xFF1e3c72),
                ),
              ),
              const SpaceHeight(16),
              Container(
                width: double.infinity,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.grey[300]!,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SpaceHeight(16),
              _buildTimeCardInfoRow(
                icon: Icons.schedule_rounded,
                label: 'Jam Kerja',
                value: '$startTime - $endTime',
              ),
              const SpaceHeight(12),
              _buildTimeCardInfoRow(
                icon: Icons.location_on_rounded,
                label: 'Lokasi Absen',
                value: _formatAttendanceLocation(attendanceAddress),
                maxLines: 2,
              ),
              const SpaceHeight(12),
              _buildTimeCardInfoRow(
                icon: Icons.work_outline_rounded,
                label: 'Mode Kerja',
                value: workMode,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeCardInfoRow({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF1e3c72).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFF1e3c72),
          ),
        ),
        const SpaceWidth(10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SpaceWidth(8),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuGrid() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1e3c72), Color(0xFF3b82c9)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.apps_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SpaceWidth(16),
              Text(
                'Tindakan Cepat',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SpaceHeight(24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
            children: [
              _buildAttendanceButton(isCheckIn: true),
              _buildAttendanceButton(isCheckIn: false),
              _buildModernMenuButton(
                icon: Icons.event_busy_rounded,
                label: 'Izin/Cuti',
                subtitle: 'Ajukan permohonan Izin/Cuti',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                ),
                onPressed: () async {
                  await _checkBackendAndNavigate(() {
                    context.push(const LeavePage());
                  });
                },
              ),
              _buildModernMenuButton(
                icon: Icons.access_time_filled_rounded,
                label: 'Lembur',
                subtitle: 'Ajukan permohonan Lembur',
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                ),
                onPressed: () async {
                  await _checkBackendAndNavigate(() {
                    context.push(const OvertimePage());
                  });
                },
              ),
            ],
          ),

          // Presensi jarak jauh punya pintu masuk sendiri: aturannya berbeda
          // (tanpa validasi radius, wajib foto & catatan aktivitas), jadi
          // digabung ke tombol absen biasa hanya akan membingungkan.
          if (_remoteAllowed) ...[
            const SpaceHeight(20),
            _buildRemoteAttendanceCard(),
          ],
        ],
      ),
    );
  }

  /// Kartu presensi WFH/WFA — terpisah dari tombol absen kantor.
  Widget _buildRemoteAttendanceCard() {
    return BlocBuilder<IsCheckedinBloc, IsCheckedinState>(
      builder: (context, state) {
        final isCheckedin = state.maybeWhen(
          orElse: () => false,
          success: (data) => data.isCheckedin,
        );
        final isCheckedout = state.maybeWhen(
          orElse: () => false,
          success: (data) => data.isCheckedout,
        );

        // Kartu ini khusus memulai hari kerja jarak jauh. Absen pulang tidak
        // bergantung mode — server memakai mode dari data absen masuk — jadi
        // jalurnya tetap lewat tombol "Absen Pulang" agar tidak ada dua pintu
        // untuk tindakan yang sama.
        final done = isCheckedin && isCheckedout;
        final label = done
            ? 'Presensi Hari Ini Selesai'
            : (isCheckedin ? 'Sudah Absen Masuk' : 'Absen Masuk WFH/WFA');
        final subtitle = done
            ? 'Absen masuk dan pulang sudah tercatat'
            : (isCheckedin
                ? 'Gunakan tombol Absen Pulang untuk mengakhiri hari kerja'
                : 'Presensi dari rumah atau mana saja, dengan foto dan '
                    'catatan aktivitas');
        final disabled = done || isCheckedin;

        return Opacity(
          opacity: disabled ? 0.55 : 1,
          child: GestureDetector(
            onTap: disabled
                ? null
                : () => _openAttendance(
                      attendanceType: 'location_based_only',
                      scope: AttendanceScope.remote,
                    ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B4DFF), Color(0xFF9E6BFF)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B4DFF).withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.home_work_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SpaceWidth(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SpaceHeight(2),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!disabled)
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceButton({required bool isCheckIn}) {
    return BlocBuilder<GetCompanyBloc, GetCompanyState>(
      builder: (context, companyState) {
        final attendanceType = companyState.maybeWhen(
          orElse: () => 'location_based_only',
          success: (data) => data.attendanceType ?? 'location_based_only',
        );

        return BlocBuilder<IsCheckedinBloc, IsCheckedinState>(
          builder: (context, state) {
            final isCheckedin = state.maybeWhen(
              orElse: () => false,
              success: (data) => data.isCheckedin,
            );
            final isCheckout = state.maybeWhen(
              orElse: () => false,
              success: (data) => data.isCheckedout,
            );

            return _buildModernAttendanceButton(
              isCheckIn: isCheckIn,
              isCheckedin: isCheckedin,
              isCheckout: isCheckout,
              onPressed: () => _openAttendance(
                attendanceType: attendanceType,
                scope: AttendanceScope.office,
              ),
            );
          },
        );
      },
    );
  }

  /// Buka halaman presensi.
  ///
  /// Seluruh validasi — radius, fake GPS, sudah absen, sedang cuti, wajib
  /// foto/catatan — kini ditentukan server lewat `GET /api/attendance/pre-check`
  /// dan ditampilkan di [AttendancePage], jadi aplikasi tidak lagi menebak
  /// aturannya sendiri.
  Future<void> _openAttendance({
    required String attendanceType,
    required AttendanceScope scope,
  }) async {
    // Pengenalan wajah tetap butuh wajah terdaftar sebelum kamera dibuka.
    final needsFace = attendanceType == 'pengenalan_wajah_saja' ||
        attendanceType == 'face_recognition_only' ||
        attendanceType == 'hybrid';
    if (needsFace &&
        FaceEngineProvider.isSupported &&
        (faceEmbedding == null || faceEmbedding!.isEmpty)) {
      _showRegisterFaceDialog();
      return;
    }

    await _checkBackendAndNavigate(() {
      context.push(AttendancePage(scope: scope)).then((_) {
        if (mounted) _onRefresh();
      });
    });
  }



  Future<void> _checkBackendAndNavigate(Function navigate) async {
    // Show loading indicator
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );

    // Check backend connection
    final isConnected = await BackendConnectionHelper.checkBackendSocket();

    // Close loading dialog
    if (mounted) {
      Navigator.pop(context);
    }

    if (!mounted) return;

    if (isConnected) {
      // Backend is reachable, proceed with navigation
      navigate();
    } else {
      // Backend is not reachable, show error dialog
      BackendConnectionDialog.show(
        context,
        customMessage: 'Tidak dapat terhubung ke backend saat ini',
      );
    }
  }

  void _showRegisterFaceDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e3c72).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.face_rounded,
                  color: Color(0xFF1e3c72),
                  size: 32,
                ),
              ),
              const SpaceHeight(16),
              Text(
                'Daftarkan Wajah Terlebih Dahulu',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SpaceHeight(8),
              Text(
                'Anda perlu mendaftarkan wajah terlebih dahulu sebelum menggunakan absensi wajah. Ingin mendaftar sekarang?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SpaceHeight(24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(context),
                          child: Center(
                            child: Text(
                              'Nanti',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SpaceWidth(12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1e3c72), Color(0xFF3b82c9)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(const RegisterFacePage());
                          },
                          child: Center(
                            child: Text(
                              'Daftar Sekarang',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildModernMenuButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SpaceHeight(8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            // const SpaceHeight(2),
            // Text(
            //   subtitle,
            //   style: GoogleFonts.poppins(
            //     fontSize: 11,
            //     fontWeight: FontWeight.w400,
            //     color: Colors.white.withValues(alpha: 0.8),
            //   ),
            //   textAlign: TextAlign.center,
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAttendanceButton({
    required bool isCheckIn,
    required bool isCheckedin,
    required bool isCheckout,
    required VoidCallback onPressed,
  }) {
    final bool isDisabled =
        isCheckIn ? isCheckedin : !isCheckedin || isCheckout;

    final String label = isCheckIn ? 'Masuk' : 'Pulang';
    final IconData icon =
        isCheckIn ? Icons.login_rounded : Icons.logout_rounded;

    final LinearGradient gradient = isCheckIn
        ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF45A049)])
        : const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFE57373)]);

    final LinearGradient disabledGradient =
        const LinearGradient(colors: [Color(0xFFBDBDBD), Color(0xFF9E9E9E)]);

    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isDisabled ? disabledGradient : gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDisabled
                  ? Colors.grey.withValues(alpha: 0.3)
                  : gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SpaceHeight(8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SpaceHeight(2),
          ],
        ),
      ),
    );
  }
}
