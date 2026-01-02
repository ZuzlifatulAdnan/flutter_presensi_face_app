import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_absensi_app/core/helper/radius_calculate.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/get_company/get_company_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/is_checkedin/is_checkedin_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/pages/attandences/face_detector_checkin_page.dart';
import 'package:flutter_absensi_app/presentation/home/pages/attandences/attendance_result_page.dart';
import 'package:flutter_absensi_app/presentation/home/pages/attandences/scanner_page.dart';
import 'package:flutter_absensi_app/presentation/leaves/pages/leave_page.dart';
import 'package:flutter_absensi_app/presentation/overtimes/pages/overtime_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';
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
  double? latitude;
  double? longitude;

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
    try {
      Location location = Location();
      bool serviceEnabled;
      PermissionStatus permissionGranted;
      LocationData locationData;

      serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      locationData = await location.getLocation();
      latitude = locationData.latitude;
      longitude = locationData.longitude;
      setState(() {});
    } on PlatformException catch (e) {
      if (e.code == 'IO_ERROR') {
        debugPrint('Network error occurred: ${e.message}');
      } else {
        debugPrint('Failed to lookup coordinates: ${e.message}');
      }
    } catch (e) {
      debugPrint('Unknown error occurred: $e');
    }
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

    // Wait a bit for the blocs to process
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {});
    }
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
    return FutureBuilder(
      future: AuthLocalDatasource().getAuthData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingHeader();
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildFallbackHeader();
        }

        final authData = snapshot.data!;
        final user = authData.user;
        final role = authData.role ?? user?.role ?? '-';
        final position = authData.position?.name ?? '-';
        final departmentName =
            authData.department?.name ?? user?.departemen?.name ?? '-';
        final shiftName =
            authData.defaultShift?.name ?? user?.shiftKerja?.name ?? '-';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child:
                          user?.imageUrl != null && user!.imageUrl!.isNotEmpty
                              ? Image.network(
                                  user.imageUrl!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        size: 28,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                    ),
                  ),
                  const SpaceWidth(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?.name ?? 'User'}',
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
                            color: Colors.white.withOpacity(0.9),
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
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.badge_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SpaceWidth(8),
                        Expanded(
                          child: Text(
                            'Role: $role',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SpaceHeight(6),
                    Row(
                      children: [
                        Icon(
                          Icons.business_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SpaceWidth(8),
                        Expanded(
                          child: Text(
                            'Dept: $departmentName',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SpaceHeight(6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SpaceWidth(8),
                        Expanded(
                          child: Text(
                            'Shift: $shiftName',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.person,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SpaceWidth(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, User',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SpaceHeight(4),
                Text(
                  'Have a productive day!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              color: Colors.white.withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SpaceHeight(8),
                Container(
                  height: 14,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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

        if (snapshot.hasData && snapshot.data != null) {
          final authData = snapshot.data!;
          startTime = authData.user?.shiftKerja?.startTime ??
              authData.defaultShiftDetail?.startTime?.toFormattedTime() ??
              '08:00';
          endTime = authData.user?.shiftKerja?.endTime ??
              authData.defaultShiftDetail?.endTime?.toFormattedTime() ??
              '17:00';
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Jam Kerja',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '$startTime - $endTime',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
            color: Colors.black.withOpacity(0.1),
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
        ],
      ),
    );
  }

  Widget _buildAttendanceButton({required bool isCheckIn}) {
    return BlocBuilder<GetCompanyBloc, GetCompanyState>(
      builder: (context, state) {
        final latitudePoint = state.maybeWhen(
          orElse: () => 0.0,
          success: (data) => double.parse(data.latitude!),
        );
        final longitudePoint = state.maybeWhen(
          orElse: () => 0.0,
          success: (data) => double.parse(data.longitude!),
        );
        final radiusPoint = state.maybeWhen(
          orElse: () => 0.0,
          success: (data) => double.parse(data.radiusKm!),
        );
        final attendanceType = state.maybeWhen(
          orElse: () => 'Location',
          success: (data) => data.attendanceType!,
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
              onPressed: () => _handleAttendance(
                isCheckIn: isCheckIn,
                isCheckedin: isCheckedin,
                isCheckout: isCheckout,
                latitudePoint: latitudePoint,
                longitudePoint: longitudePoint,
                radiusPoint: radiusPoint,
                attendanceType: attendanceType,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFaceAttendanceButton() {
    return BlocBuilder<IsCheckedinBloc, IsCheckedinState>(
      builder: (context, state) {
        final isCheckout = state.maybeWhen(
          orElse: () => false,
          success: (data) => data.isCheckedout,
        );
        final isCheckIn = state.maybeWhen(
          orElse: () => false,
          success: (data) => data.isCheckedin,
        );

        return BlocBuilder<GetCompanyBloc, GetCompanyState>(
          builder: (context, state) {
            final latitudePoint = state.maybeWhen(
              orElse: () => 0.0,
              success: (data) => double.parse(data.latitude!),
            );
            final longitudePoint = state.maybeWhen(
              orElse: () => 0.0,
              success: (data) => double.parse(data.longitude!),
            );
            final radiusPoint = state.maybeWhen(
              orElse: () => 0.0,
              success: (data) => double.parse(data.radiusKm!),
            );

            String buttonText = 'Kehadiran Hari Ini';
            if (!isCheckIn) {
              buttonText = 'Masuk dengan Wajah';
            } else if (!isCheckout) {
              buttonText = 'Pulang dengan Wajah';
            } else {
              buttonText = 'Kehadiran Selesai';
            }

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1e3c72),
                    Color(0xFF3b82c9),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1e3c72).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _handleFaceAttendance(
                    isCheckIn: isCheckIn,
                    isCheckout: isCheckout,
                    latitudePoint: latitudePoint,
                    longitudePoint: longitudePoint,
                    radiusPoint: radiusPoint,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Assets.icons.attendance.svg(
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          width: 24,
                          height: 24,
                        ),
                        const SpaceWidth(12),
                        Text(
                          buttonText,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAttendance({
    required bool isCheckIn,
    required bool isCheckedin,
    required bool isCheckout,
    required double latitudePoint,
    required double longitudePoint,
    required double radiusPoint,
    required String attendanceType,
  }) async {
    try {
      // Check face embedding FIRST for Face attendance type
      if (attendanceType == 'pengenalan_wajah_saja' ||
          attendanceType == 'hybrid') {
        if (faceEmbedding == null || faceEmbedding!.isEmpty) {
          _showRegisterFaceDialog();
          return;
        }
      }

      // THEN check location and other validations
      final distanceKm = RadiusCalculate.calculateDistance(
        latitude ?? 0.0,
        longitude ?? 0.0,
        latitudePoint,
        longitudePoint,
      );

      final position = await Geolocator.getCurrentPosition();

      if (position.isMocked) {
        _showFakeGpsDialog();
        return;
      }

      if (distanceKm > radiusPoint &&
          (attendanceType == 'location_based_only' ||
              attendanceType == 'hybrid')) {
        _showOutOfAreaDialog(
          distance: distanceKm,
          allowedRadius: radiusPoint,
        );
        return;
      }

      if (isCheckIn) {
        if (isCheckedin) {
          _showModernDialog(
            'Already Checked In',
            'You have already checked in today.',
            Icons.check_circle_rounded,
            Colors.green,
          );
          return;
        }
      } else {
        if (!isCheckedin) {
          _showModernDialog(
            'Check In Required',
            'Please check in first before checking out.',
            Icons.info_rounded,
            Colors.blue,
          );
          return;
        }
        if (isCheckout) {
          _showModernDialog(
            'Already Checked Out',
            'You have already checked out today.',
            Icons.check_circle_rounded,
            Colors.green,
          );
          return;
        }
      }

      _navigateToAttendance(attendanceType, isCheckIn);
    } catch (e) {
      _showModernDialog(
        'Error',
        'An error occurred: $e',
        Icons.error_rounded,
        Colors.red,
      );
    }
  }

  Future<void> _handleFaceAttendance({
    required bool isCheckIn,
    required bool isCheckout,
    required double latitudePoint,
    required double longitudePoint,
    required double radiusPoint,
  }) async {
    try {
      final distanceKm = RadiusCalculate.calculateDistance(
        latitude ?? 0.0,
        longitude ?? 0.0,
        latitudePoint,
        longitudePoint,
      );

      final position = await Geolocator.getCurrentPosition();

      if (position.isMocked) {
        _showModernSnackBar(
          'You are using fake location',
          Icons.error_outline,
          Colors.red,
        );
        return;
      }

      if (distanceKm > radiusPoint) {
        _showModernSnackBar(
          'You are outside the attendance area',
          Icons.location_off,
          Colors.orange,
        );
        return;
      }

      if (!isCheckIn) {
        await _checkBackendAndNavigate(() {
          context.push(FaceDetectorCheckinPage(
            isCheckedIn: true,
            latitude: latitude,
            longitude: longitude,
          ));
        });
      } else if (!isCheckout) {
        await _checkBackendAndNavigate(() {
          context.push(FaceDetectorCheckinPage(
            isCheckedIn: false,
            latitude: latitude,
            longitude: longitude,
          ));
        });
      } else {
        _showModernSnackBar(
          'You have completed attendance today',
          Icons.check_circle,
          Colors.green,
        );
      }
    } catch (e) {
      _showModernSnackBar(
        'Error: $e',
        Icons.error,
        Colors.red,
      );
    }
  }

  void _showModernDialog(
      String title, String message, IconData icon, Color color) {
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SpaceHeight(16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SpaceHeight(8),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SpaceHeight(24),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context),
                    child: Center(
                      child: Text(
                        'OK',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModernSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SpaceWidth(8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
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

  Future<void> _navigateToAttendance(
      String attendanceType, bool isCheckIn) async {
    await _checkBackendAndNavigate(() {
      if (attendanceType == 'face_recognition_only' ||
          attendanceType == 'hybrid') {
        context.push(FaceDetectorCheckinPage(
          isCheckedIn: isCheckIn,
          latitude: latitude,
          longitude: longitude,
        ));
      } else {
        // For location_based_only and other types, pass lat/long
        context.push(AttendanceResultPage(
          isCheckin: isCheckIn,
          isMatch: true,
          attendanceType: attendanceType,
          latitude: latitude,
          longitude: longitude,
        ));
      }
    });
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
                  color: const Color(0xFF1e3c72).withOpacity(0.1),
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
                'Register Face Required',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SpaceHeight(8),
              Text(
                'You need to register your face first before using face attendance. Would you like to register now?',
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
                              'Later',
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
                              'Register Now',
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

  void _showFakeGpsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.1),
                      Colors.red.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.gps_off_rounded,
                  color: Colors.red[700],
                  size: 48,
                ),
              ),
              const SpaceHeight(24),
              Text(
                'Fake GPS Terdeteksi!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                ),
                textAlign: TextAlign.center,
              ),
              const SpaceHeight(12),
              Text(
                'Sistem mendeteksi bahwa HP Anda menggunakan aplikasi fake GPS atau mock location.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SpaceHeight(8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SpaceWidth(12),
                    Expanded(
                      child: Text(
                        'Harap nonaktifkan fake GPS terlebih dahulu untuk melanjutkan absensi.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SpaceHeight(28),
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red[600]!,
                      Colors.red[700]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context),
                    child: Center(
                      child: Text(
                        'Mengerti',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOutOfAreaDialog({
    required double distance,
    required double allowedRadius,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.1),
                      Colors.orange.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.location_off_rounded,
                  color: Colors.orange[700],
                  size: 48,
                ),
              ),
              const SpaceHeight(24),
              Text(
                'Lokasi Di Luar Area!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                ),
                textAlign: TextAlign.center,
              ),
              const SpaceHeight(12),
              Text(
                'Anda berada di luar jangkauan area absensi yang telah ditentukan oleh kantor.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SpaceHeight(16),
              // Distance information box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.straighten_rounded,
                          color: Colors.red[700],
                          size: 20,
                        ),
                        const SpaceWidth(8),
                        Text(
                          'Informasi Jarak',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                    const SpaceHeight(12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jarak Anda:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${distance.toStringAsFixed(2)} km',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SpaceHeight(6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Radius Maksimal:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${allowedRadius.toStringAsFixed(2)} km',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SpaceHeight(6),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.red.withOpacity(0.2),
                    ),
                    const SpaceHeight(6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kelebihan Jarak:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${(distance - allowedRadius).toStringAsFixed(2)} km',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.red[900],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SpaceHeight(12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    const SpaceWidth(12),
                    Expanded(
                      child: Text(
                        'Harap mendekat ke lokasi kantor untuk dapat melakukan absensi.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SpaceHeight(28),
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange[600]!,
                      Colors.orange[700]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context),
                    child: Center(
                      child: Text(
                        'Mengerti',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
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
              color: gradient.colors.first.withOpacity(0.3),
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
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
            //     color: Colors.white.withOpacity(0.8),
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
    final String subtitle = isCheckIn ? 'Start your day' : 'End your day';
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
                  ? Colors.grey.withOpacity(0.3)
                  : gradient.colors.first.withOpacity(0.3),
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
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
