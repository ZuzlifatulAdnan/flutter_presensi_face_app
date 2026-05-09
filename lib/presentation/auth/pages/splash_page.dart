import 'package:flutter/material.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';
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
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      final isAuth = await AuthLocalDatasource().isAuth();
      if (isAuth) {
        context.pushReplacement(const MainPage());
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
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 80,
                color: Colors.white,
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
                    'Absen Devtech KI',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SpaceHeight(8),
                  Text(
                    'Devtech',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 4.0,
                    ),
                  ),
                  const SpaceHeight(16),
                  Container(
                    width: 60,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SpaceHeight(16),
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                const SpaceHeight(24),
                Text(
                  'Memuat...',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
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