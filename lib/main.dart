import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_absensi_app/core/config/app_config.dart';
import 'package:flutter_absensi_app/core/helper/attendance_notification_service.dart';
import 'package:flutter_absensi_app/core/helper/device_info_helper.dart';
import 'package:flutter_absensi_app/core/network/api_client.dart';
import 'package:flutter_absensi_app/core/theme/app_theme.dart';
import 'package:flutter_absensi_app/data/datasources/attendance_remote_datasource.dart';
import 'package:flutter_absensi_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_absensi_app/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_absensi_app/data/datasources/leave_remote_datasource.dart';
import 'package:flutter_absensi_app/data/datasources/overtime_remote_datasource.dart';
import 'package:flutter_absensi_app/data/datasources/permisson_remote_datasource.dart';
import 'package:flutter_absensi_app/data/datasources/user_remote_datasource.dart';
import 'package:flutter_absensi_app/data/models/response/app_settings_model.dart';
import 'package:flutter_absensi_app/data/models/response/qr_absen_remote_datasource.dart';
import 'package:flutter_absensi_app/presentation/auth/bloc/login/login_bloc.dart';
import 'package:flutter_absensi_app/presentation/auth/bloc/logout/logout_bloc.dart';
import 'package:flutter_absensi_app/presentation/auth/pages/login_page.dart';
import 'package:flutter_absensi_app/presentation/auth/pages/splash_page.dart';
import 'package:flutter_absensi_app/presentation/history/blocs/attendance_summary/attendance_summary_bloc.dart';
import 'package:flutter_absensi_app/presentation/history/blocs/get_all_attendances/get_all_attendances_bloc.dart';
import 'package:flutter_absensi_app/presentation/history/blocs/get_attendance_by_date/get_attendance_by_date_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/add_permission/add_permission_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/attendance_precheck/attendance_precheck_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/check_qr/check_qr_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/checkin_attendance/checkin_attendance_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/checkout_attendance/checkout_attendance_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/get_company/get_company_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/get_qrcode_checkin/get_qrcode_checkin_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/get_qrcode_checkout/get_qrcode_checkout_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/is_checkedin/is_checkedin_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/update_user_register_face/update_user_register_face_bloc.dart';
import 'package:flutter_absensi_app/presentation/leaves/bloc/cancel_leave/cancel_leave_bloc.dart';
import 'package:flutter_absensi_app/presentation/leaves/bloc/create_leave/create_leave_bloc.dart';
import 'package:flutter_absensi_app/presentation/leaves/bloc/get_all_leaves/get_all_leaves_bloc.dart';
import 'package:flutter_absensi_app/presentation/leaves/bloc/leave_balance/leave_balance_bloc.dart';
import 'package:flutter_absensi_app/presentation/leaves/bloc/leave_type/leave_type_bloc.dart';
import 'package:flutter_absensi_app/presentation/overtimes/blocs/end_overtime/end_overtime_bloc.dart';
import 'package:flutter_absensi_app/presentation/overtimes/blocs/get_overtime_status/get_overtime_status_bloc.dart';
import 'package:flutter_absensi_app/presentation/overtimes/blocs/get_overtimes/get_overtimes_bloc.dart';
import 'package:flutter_absensi_app/presentation/overtimes/blocs/start_overtime/start_overtime_bloc.dart';
import 'package:flutter_absensi_app/presentation/profile/bloc/get_user/get_user_bloc.dart';
import 'package:flutter_absensi_app/presentation/profile/bloc/update_password/update_password_bloc.dart';
import 'package:flutter_absensi_app/presentation/profile/bloc/update_user/update_user_bloc.dart';

/// Navigator global — dipakai untuk memaksa kembali ke halaman masuk saat
/// server menjawab 401, dari lapisan mana pun.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  // Pengaturan tersimpan dimuat lebih dulu supaya splash langsung tampil
  // dengan nama, logo, dan warna yang benar walau perangkat sedang offline.
  await AppConfig.loadCached();
  AppConfig.installedVersion = await DeviceInfoHelper.appVersion();

  await AttendanceNotificationService().initialize();

  ApiClient.onUnauthenticated = _handleSessionExpired;

  runApp(const MyApp());
}

/// Token ditolak server: bersihkan sesi dan kembalikan pengguna ke login.
Future<void> _handleSessionExpired() async {
  await AuthLocalDatasource().removeAuthData();
  await AttendanceNotificationService().cancelShiftReminder();

  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LoginBloc(AuthRemoteDatasource())),
        BlocProvider(create: (_) => LogoutBloc(AuthRemoteDatasource())),
        BlocProvider(
          create: (_) => UpdateUserRegisterFaceBloc(AuthRemoteDatasource()),
        ),
        BlocProvider(create: (_) => GetCompanyBloc(AttendanceRemoteDatasource())),
        BlocProvider(create: (_) => IsCheckedinBloc(AttendanceRemoteDatasource())),
        BlocProvider(
          create: (_) => AttendancePrecheckBloc(AttendanceRemoteDatasource()),
        ),
        BlocProvider(
          create: (_) => CheckinAttendanceBloc(AttendanceRemoteDatasource()),
        ),
        BlocProvider(
          create: (_) => CheckoutAttendanceBloc(AttendanceRemoteDatasource()),
        ),
        BlocProvider(create: (_) => AddPermissionBloc(PermissonRemoteDatasource())),
        BlocProvider(
          create: (_) => GetAttendanceByDateBloc(AttendanceRemoteDatasource()),
        ),
        BlocProvider(
          create: (_) => GetAllAttendancesBloc(AttendanceRemoteDatasource()),
        ),
        BlocProvider(
          create: (_) => AttendanceSummaryBloc(AttendanceRemoteDatasource()),
        ),
        BlocProvider(create: (_) => CreateLeaveBloc(LeaveRemoteDatasource())),
        BlocProvider(create: (_) => CancelLeaveBloc(LeaveRemoteDatasource())),
        BlocProvider(create: (_) => LeaveTypeBloc(LeaveRemoteDatasource())),
        BlocProvider(create: (_) => LeaveBalanceBloc(LeaveRemoteDatasource())),
        BlocProvider(create: (_) => GetAllLeavesBloc(LeaveRemoteDatasource())),
        BlocProvider(create: (_) => GetOvertimesBloc(OvertimeRemoteDatasource())),
        BlocProvider(
          create: (_) => GetOvertimeStatusBloc(OvertimeRemoteDatasource()),
        ),
        BlocProvider(create: (_) => StartOvertimeBloc(OvertimeRemoteDatasource())),
        BlocProvider(create: (_) => EndOvertimeBloc(OvertimeRemoteDatasource())),
        BlocProvider(create: (_) => CheckQrBloc(QrAbsenRemoteDatasource())),
        BlocProvider(create: (_) => GetQrcodeCheckinBloc()),
        BlocProvider(create: (_) => GetQrcodeCheckoutBloc()),
        BlocProvider(create: (_) => GetUserBloc(UserRemoteDatasource())),
        BlocProvider(create: (_) => UpdateUserBloc(UserRemoteDatasource())),
        BlocProvider(create: (_) => UpdatePasswordBloc(UserRemoteDatasource())),
      ],
      // Nama dan warna aplikasi mengikuti `/api/app-settings`, jadi seluruh
      // MaterialApp dibangun ulang saat admin mengubah identitas visual.
      child: ValueListenableBuilder<AppSettingsModel>(
        valueListenable: AppConfig.settings,
        builder: (context, settings, _) => MaterialApp(
          navigatorKey: appNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: settings.appName,
          theme: AppTheme.light(settings.theme.primary),
          home: const SplashPage(),
        ),
      ),
    );
  }
}
