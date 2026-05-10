import 'package:flutter/material.dart';
import 'package:flutter_absensi_app/core/helper/attendance_notification_service.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_absensi_app/presentation/auth/bloc/login/login_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/core.dart';
import '../../home/pages/main_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  bool isShowPassword = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _buttonController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    emailController = TextEditingController();
    passwordController = TextEditingController();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _buttonController = AnimationController(
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
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _buttonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fadeController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        _slideController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _buttonController.forward();
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1e3c72), // Deep professional blue
              Color(0xFF2a5298), // Professional blue
              Color(0xFF3b82c9), // Lighter corporate blue
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SpaceHeight(40),

                  // App Logo and Title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            Assets.images.logoWhite.path,
                            width: 64,
                            height: 64,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SpaceHeight(20),
                        Text(
                          'ABSEN DEVTECH',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'PRESENSI & KEPEGAWAIAN',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 3.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SpaceHeight(30),

                  // Login Card
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(28),
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
                            Text(
                              'Selamat Datang',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.black,
                              ),
                            ),
                            const SpaceHeight(8),
                            Text(
                              'Masuk untuk melanjutkan ke akun Anda',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppColors.grey,
                              ),
                            ),

                            const SpaceHeight(24),

                            // Email Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black,
                                  ),
                                ),
                                const SpaceHeight(8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.lightSheet,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.light,
                                      width: 1,
                                    ),
                                  ),
                                  child: CustomTextField(
                                    controller: emailController,
                                    label: 'Masukan email Anda',
                                    showLabel: false,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: SvgPicture.asset(
                                        Assets.icons.email.path,
                                        height: 20,
                                        width: 20,
                                        colorFilter: ColorFilter.mode(
                                          AppColors.grey,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SpaceHeight(16),

                            // Password Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Password',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black,
                                  ),
                                ),
                                const SpaceHeight(8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.lightSheet,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.light,
                                      width: 1,
                                    ),
                                  ),
                                  child: CustomTextField(
                                    controller: passwordController,
                                    label: 'Masukan password Anda',
                                    showLabel: false,
                                    obscureText: !isShowPassword,
                                    textInputAction: TextInputAction.done,
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: SvgPicture.asset(
                                        Assets.icons.password.path,
                                        height: 20,
                                        width: 20,
                                        colorFilter: ColorFilter.mode(
                                          AppColors.grey,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        isShowPassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: AppColors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          isShowPassword = !isShowPassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SpaceHeight(28),

                            // Login Button
                            ScaleTransition(
                              scale: _buttonAnimation,
                              child: BlocListener<LoginBloc, LoginState>(
                                listener: (context, state) {
                                  state.maybeWhen(
                                    orElse: () {},
                                    success: (data) async {
                                      await AuthLocalDatasource()
                                          .saveAuthData(data);
                                      // Jadwalkan notifikasi pengingat absen
                                      // sesuai shift kerja (15 menit sebelum)
                                      final shiftStart =
                                          data.user?.shiftKerja?.startTime ??
                                              data.defaultShiftDetail
                                                  ?.startTime;
                                      if (shiftStart != null &&
                                          shiftStart.isNotEmpty) {
                                        final shiftName =
                                            data.defaultShift?.name ??
                                                data.user?.shiftKerja?.name ??
                                                'Shift Kerja';
                                        // Parse format "HH:mm" dari startTime
                                        String parsedTime = shiftStart;
                                        final dtParsed =
                                            DateTime.tryParse(shiftStart);
                                        if (dtParsed != null) {
                                          parsedTime =
                                              '${dtParsed.hour.toString().padLeft(2, '0')}:${dtParsed.minute.toString().padLeft(2, '0')}';
                                        } else {
                                          final m = RegExp(r'(\d{1,2}):(\d{2})')
                                              .firstMatch(shiftStart);
                                          if (m != null) {
                                            parsedTime =
                                                '${m.group(1)!.padLeft(2, '0')}:${m.group(2)!}';
                                          }
                                        }
                                        await AttendanceNotificationService()
                                            .scheduleShiftReminder(
                                          shiftStartTime: parsedTime,
                                          shiftName: shiftName,
                                        );
                                      }
                                      if (context.mounted) {
                                        context
                                            .pushReplacement(const MainPage());
                                      }
                                    },
                                    error: (message) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.error_outline_rounded,
                                                color: Colors.white,
                                              ),
                                              const SpaceWidth(12),
                                              Expanded(
                                                child: Text(
                                                  message,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: AppColors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: BlocBuilder<LoginBloc, LoginState>(
                                  builder: (context, state) {
                                    return state.maybeWhen(
                                      orElse: () {
                                        return Container(
                                          width: double.infinity,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF1e3c72),
                                                Color(0xFF3b82c9),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF1e3c72)
                                                    .withOpacity(0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              onTap: () {
                                                context.read<LoginBloc>().add(
                                                      LoginEvent.login(
                                                        emailController.text,
                                                        passwordController.text,
                                                      ),
                                                    );
                                              },
                                              child: Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.login_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    const SpaceWidth(8),
                                                    Text(
                                                      'Sign In',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                      loading: () {
                                        return Container(
                                          width: double.infinity,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: AppColors.light,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                                const SpaceWidth(12),
                                                Text(
                                                  'Signing In...',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SpaceHeight(24),

                  // Footer
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      '© 2026 DevTech. Kominfo Pringsewu.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SpaceHeight(120),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
