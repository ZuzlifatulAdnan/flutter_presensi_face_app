
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service untuk mengelola notifikasi pengingat absen sesuai shift kerja.
/// - Absen masuk: 15 menit sebelum jam mulai shift.
/// - Absen pulang: tepat pada jam selesai shift.
class AttendanceNotificationService {
  static final AttendanceNotificationService _instance =
      AttendanceNotificationService._internal();
  factory AttendanceNotificationService() => _instance;
  AttendanceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _checkInReminderId = 1001;
  static const int _checkOutReminderId = 1002;
  static const String _channelId = 'attendance_reminder';
  static const String _channelName = 'Pengingat Absen';
  static const String _channelDesc =
      'Notifikasi pengingat absen masuk dan pulang sesuai shift kerja';

  bool _initialized = false;

  /// Inisialisasi plugin notifikasi. Dipanggil sekali di main().
  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notifikasi diklik: ${details.payload}');
      },
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }

    _initialized = true;
    debugPrint('[AttendanceNotification] Initialized');
  }

  /// Jadwalkan notifikasi pengingat absen masuk dan pulang.
  /// [shiftStartTime] dan [shiftEndTime] menerima format apapun yang mengandung
  /// pola "HH:mm" (mis. "08:00", "08:00:00", atau ISO 8601 dengan timezone).
  Future<void> scheduleShiftReminder({
    required String shiftStartTime,
    String? shiftEndTime,
    String shiftName = 'Shift Kerja',
  }) async {
    if (!_initialized) await initialize();

    await cancelShiftReminder();

    final start = _parseTimeString(shiftStartTime);
    if (start != null) {
      await _scheduleAt(
        id: _checkInReminderId,
        hour: start.hour,
        minute: start.minute,
        offsetMinutes: -15,
        title: '⏰ Pengingat Absen Masuk',
        body:
            '$shiftName dimulai pukul ${_formatHHmm(start.hour, start.minute)}. '
            'Segera lakukan absen masuk agar tidak terlambat!',
        payload: 'shift_check_in_reminder',
      );
    } else {
      debugPrint(
          '[AttendanceNotification] Gagal parse jam masuk: $shiftStartTime');
    }

    if (shiftEndTime != null && shiftEndTime.isNotEmpty) {
      final end = _parseTimeString(shiftEndTime);
      if (end != null) {
        await _scheduleAt(
          id: _checkOutReminderId,
          hour: end.hour,
          minute: end.minute,
          offsetMinutes: 0,
          title: '🚪 Pengingat Absen Pulang',
          body:
              '$shiftName selesai pukul ${_formatHHmm(end.hour, end.minute)}. '
              'Jangan lupa lakukan absen pulang!',
          payload: 'shift_check_out_reminder',
        );
      } else {
        debugPrint(
            '[AttendanceNotification] Gagal parse jam pulang: $shiftEndTime');
      }
    }
  }

  /// Jadwalkan satu notifikasi harian pada jam:menit + offsetMinutes.
  Future<void> _scheduleAt({
    required int id,
    required int hour,
    required int minute,
    required int offsetMinutes,
    required String title,
    required String body,
    required String payload,
  }) async {
    final jakartaLocation = tz.getLocation('Asia/Jakarta');
    final now = tz.TZDateTime.now(jakartaLocation);

    var scheduledDate = tz.TZDateTime(
      jakartaLocation,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(Duration(minutes: offsetMinutes));

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500]);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notif_absen'),
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      icon: '@mipmap/launcher_icon',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      color: const Color(0xFF1e3c72),
      ticker: 'Pengingat Absen',
      fullScreenIntent: false,
    );

    const darwinDetails = DarwinNotificationDetails(
      sound: 'notif_absen.mp3',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );

    debugPrint(
        '[AttendanceNotification] id=$id dijadwalkan pada $scheduledDate');
  }

  /// Batalkan notifikasi pengingat absen yang sudah dijadwalkan.
  Future<void> cancelShiftReminder() async {
    await _plugin.cancel(id: _checkInReminderId);
    await _plugin.cancel(id: _checkOutReminderId);
    debugPrint('[AttendanceNotification] Jadwal notifikasi dibatalkan');
  }

  /// Batalkan semua notifikasi.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Tampilkan notifikasi instan (untuk testing / debugging).
  Future<void> showInstantReminder({
    required String shiftName,
    required String shiftStartTime,
  }) async {
    if (!_initialized) await initialize();

    final vibrationPattern = Int64List.fromList([0, 500, 200, 500]);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notif_absen'),
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      icon: '@mipmap/launcher_icon',
      color: const Color(0xFF1e3c72),
    );

    const darwinDetails = DarwinNotificationDetails(
      sound: 'notif_absen.mp3',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(
      id: _checkInReminderId,
      title: '⏰ Pengingat Absen Masuk',
      body: '$shiftName dimulai pukul $shiftStartTime. '
          'Segera lakukan absen masuk agar tidak terlambat!',
      notificationDetails: notificationDetails,
      payload: 'shift_check_in_reminder',
    );
  }

  /// Ekstrak jam & menit lokal dari string apapun.
  /// Diutamakan regex HH:mm supaya tidak salah ketika backend mengirim ISO 8601
  /// dengan offset +07:00 (DateTime.parse otomatis normalisasi ke UTC, sehingga
  /// .hour jadi mundur 7 jam).
  static _HourMinute? _parseTimeString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(trimmed);
    if (m != null) {
      final h = int.tryParse(m.group(1)!);
      final mi = int.tryParse(m.group(2)!);
      if (h != null && mi != null && h >= 0 && h < 24 && mi >= 0 && mi < 60) {
        return _HourMinute(h, mi);
      }
    }

    final dt = DateTime.tryParse(trimmed)?.toLocal();
    if (dt != null) return _HourMinute(dt.hour, dt.minute);

    return null;
  }

  static String _formatHHmm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class _HourMinute {
  final int hour;
  final int minute;
  const _HourMinute(this.hour, this.minute);
}
