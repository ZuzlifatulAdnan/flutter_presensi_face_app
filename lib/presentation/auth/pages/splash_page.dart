import 'package:flutter/material.dart';
import 'package:flutter_absensi_app/core/config/app_config.dart';
import 'package:flutter_absensi_app/core/helper/attendance_notification_service.dart';
import 'package:flutter_absensi_app/data/datasources/app_settings_remote_datasource.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_absensi_app/data/models/response/auth_response_model.dart';
import 'package:flutter_absensi_app/presentation/app/pages/app_gate_page.dart';
import 'package:flutter_absensi_app/presentation/app/widgets/app_logo.dart';
import 'package:flutter_absensi_app/presentation/home/pages/main_page.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/core.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));

    // Start animations
    Future.delayed(const Duration(milliseconds: 300), () {
      _scaleController.forward();
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      _fadeController.forward();
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      _slideController.forward();
    });

    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Pengaturan aplikasi dimuat lebih dulu: nama, logo, warna, mode
    // pemeliharaan, dan versi minimum semuanya berasal dari sana.
    final results = await Future.wait([
      AppSettingsRemoteDatasource().getAppSettings(),
      AuthLocalDatasource().isAuth(),
      AuthLocalDatasource().getAuthData(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    if (!mounted) return;

    // Pemeliharaan dan wajib-update menghentikan alur sebelum layar apa pun
    // yang memerlukan API dibuka.
    if (AppConfig.isUnderMaintenance) {
      _replaceWith(
        AppGatePage.maintenance(
          settings: AppConfig.value.maintenance,
          onRetry: _retry,
        ),
      );
      return;
    }

    if (AppConfig.mustUpdate) {
      _replaceWith(
        AppGatePage.forceUpdate(
          version: AppConfig.value.version,
          installedVersion: AppConfig.installedVersion,
          onRetry: _retry,
        ),
      );
      return;
    }

    final isAuth = results[1] as bool;
    final authData = results[2] as AuthResponseModel?;

    if (!isAuth) {
      _replaceWith(const LoginPage());
      return;
    }

    await _scheduleShiftReminder(authData);
    if (!mounted) return;
    _replaceWith(const MainPage());
  }

  void _replaceWith(Widget page) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _retry() {
    if (!mounted) return;
    _replaceWith(const SplashPage());
  }

  /// Jadwalkan ulang notifikasi pengingat absen berdasarkan data shift.
  /// Service akan parse format jam apapun (HH:mm, HH:mm:ss, atau ISO).
  Future<void> _scheduleShiftReminder(AuthResponseModel? authData) async {
    final shiftStart = authData?.user?.shiftKerja?.startTime ??
        authData?.defaultShiftDetail?.startTime;
    if (shiftStart == null || shiftStart.isEmpty) return;

    final shiftEnd = authData?.user?.shiftKerja?.endTime ??
        authData?.defaultShiftDetail?.endTime;
    final shiftName = authData?.defaultShift?.name ??
        authData?.user?.shiftKerja?.name ??
        'Shift Kerja';

    await AttendanceNotificationService().scheduleShiftReminder(
      shiftStartTime: shiftStart,
      shiftEndTime: shiftEnd,
      shiftName: shiftName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1e3c72),  // Deep professional blue
              Color(0xFF2a5298),  // Professional blue
              Color(0xFF3b82c9),  // Lighter corporate blue
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: _buildSplashContent(),
      ),
    );
  }

  Widget _buildSplashContent() {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          // Logo Section
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: const AppLogo(size: 90, light: true),
            ),
          ),

          const SpaceHeight(40),

          // App Name
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Nama & tagline mengikuti pengaturan dari server.
                  Text(
                    AppConfig.appName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SpaceHeight(8),
                  Text(
                    (AppConfig.value.tagline ?? 'PRESENSI & KEPEGAWAIAN')
                        .toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SpaceHeight(24),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107), // Accent amber
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SpaceHeight(24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      AppConfig.value.company.name ??
                          'Dinas Komunikasi dan Informatika Pringsewu',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Loading Indicator
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SpaceHeight(24),
                Text(
                  'Memuat data...',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SpaceHeight(40),
        ],
      ),
    );
  }
}