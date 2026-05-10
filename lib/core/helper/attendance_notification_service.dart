import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service untuk mengelola notifikasi pengingat absen sesuai shift kerja.
/// Notifikasi akan muncul 15 menit sebelum jam masuk shift.
class AttendanceNotificationService {
  static final AttendanceNotificationService _instance =
      AttendanceNotificationService._internal();
  factory AttendanceNotificationService() => _instance;
  AttendanceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _reminderNotificationId = 1001;
  static const String _channelId = 'attendance_reminder';
  static const String _channelName = 'Pengingat Absen';
  static const String _channelDesc =
      'Notifikasi pengingat untuk absen masuk sesuai shift kerja';

  bool _initialized = false;

  /// Inisialisasi plugin notifikasi. Dipanggil sekali di main().
  Future<void> initialize() async {
    if (_initialized) return;

    // Inisialisasi timezone
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
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notifikasi diklik: ${details.payload}');
      },
    );

    // Request izin notifikasi Android 13+
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }

    _initialized = true;
    debugPrint('[AttendanceNotification] Initialized');
  }

  /// Jadwalkan notifikasi pengingat absen 15 menit sebelum jam masuk shift.
  /// [shiftStartTime] format "HH:mm" contoh "08:00"
  /// [shiftName] nama shift untuk ditampilkan di notifikasi
  Future<void> scheduleShiftReminder({
    required String shiftStartTime,
    String shiftName = 'Shift Kerja',
  }) async {
    if (!_initialized) await initialize();

    // Batalkan jadwal sebelumnya
    await cancelShiftReminder();

    // Parse jam dan menit dari shiftStartTime
    final timeParts = shiftStartTime.trim().split(':');
    if (timeParts.length < 2) {
      debugPrint(
          '[AttendanceNotification] Format waktu tidak valid: $shiftStartTime');
      return;
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) {
      debugPrint(
          '[AttendanceNotification] Gagal parse waktu: $shiftStartTime');
      return;
    }

    // Hitung waktu notifikasi = jam masuk - 15 menit
    final jakartaLocation = tz.getLocation('Asia/Jakarta');
    final now = tz.TZDateTime.now(jakartaLocation);

    // Buat waktu target hari ini
    var scheduledDate = tz.TZDateTime(
      jakartaLocation,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(const Duration(minutes: 15));

    // Jika waktu sudah lewat, jadwalkan untuk hari berikutnya
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint(
        '[AttendanceNotification] Jadwal notifikasi pada: $scheduledDate');

    // Pola getaran: diam, getar, diam, getar
    final vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500]);

    // Detail notifikasi Android dengan nada kustom
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

    final shiftHourStr = hour.toString().padLeft(2, '0');
    final shiftMinStr = minute.toString().padLeft(2, '0');

    await _plugin.zonedSchedule(
      _reminderNotificationId,
      '⏰ Pengingat Absen Masuk',
      '$shiftName dimulai pukul $shiftHourStr:$shiftMinStr. '
          'Segera lakukan absen masuk agar tidak terlambat!',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'shift_reminder',
    );

    debugPrint(
        '[AttendanceNotification] Notifikasi dijadwalkan pukul $shiftHourStr:$shiftMinStr '
        '(15 menit sebelum shift $shiftName)');
  }

  /// Batalkan notifikasi pengingat absen yang sudah dijadwalkan.
  Future<void> cancelShiftReminder() async {
    await _plugin.cancel(_reminderNotificationId);
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
      _reminderNotificationId,
      '⏰ Pengingat Absen Masuk',
      '$shiftName dimulai pukul $shiftStartTime. '
          'Segera lakukan absen masuk agar tidak terlambat!',
      notificationDetails,
      payload: 'shift_reminder',
    );
  }
}
