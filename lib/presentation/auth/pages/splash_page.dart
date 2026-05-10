import 'package:flutter/material.dart';
import 'package:flutter_absensi_app/core/helper/attendance_notification_service.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_absensi_app/data/models/response/auth_response_model.dart';
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
    // Jalankan pengecekan auth dan tunggu minimal waktu animasi (1.5 detik) secara bersamaan
    final results = await Future.wait([
      AuthLocalDatasource().isAuth(),
      AuthLocalDatasource().getAuthData(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    if (mounted) {
      final isAuth = results[0] as bool;
      final authData = results[1] as AuthResponseModel?;

      if (isAuth) {
        // Jadwalkan ulang notifikasi pengingat absen berdasarkan data shift
        final shiftStart = authData?.user?.shiftKerja?.startTime ??
            authData?.defaultShiftDetail?.startTime;
        if (shiftStart != null && shiftStart.isNotEmpty) {
          final shiftName = authData?.defaultShift?.name ??
              authData?.user?.shiftKerja?.name ??
              'Shift Kerja';
          String parsedTime = shiftStart;
          final dtParsed = DateTime.tryParse(shiftStart);
          if (dtParsed != null) {
            parsedTime =
                '${dtParsed.hour.toString().padLeft(2, '0')}:${dtParsed.minute.toString().padLeft(2, '0')}';
          } else {
            final m =
                RegExp(r'(\d{1,2}):(\d{2})').firstMatch(shiftStart);
            if (m != null) {
              parsedTime =
                  '${m.group(1)!.padLeft(2, '0')}:${m.group(2)!}';
            }
          }
          await AttendanceNotificationService().scheduleShiftReminder(
            shiftStartTime: parsedTime,
            shiftName: shiftName,
          );
        }
        if (mounted) context.pushReplacement(const MainPage());
      } else {
        context.pushReplacement(const LoginPage());
      }
    }
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
              child: Image.asset(
                Assets.images.logoWhite.path,
                width: 90,
                height: 90,
                fit: BoxFit.contain,
              ),
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
                  Text(
                    'ABSEN DEVTECH',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SpaceHeight(8),
                  Text(
                    'PRESENSI & KEPEGAWAIAN',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3.0,
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