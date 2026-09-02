import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_absensi_app/data/models/response/app_settings_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_precheck_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_response_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_summary_model.dart';
import 'package:flutter_absensi_app/data/models/response/leave_response_model.dart';
import 'package:flutter_absensi_app/data/datasources/user_remote_datasource.dart';

void main() {
  group('AppVersionSettings.compare', () {
    test('mengenali versi yang lebih lama, sama, dan lebih baru', () {
      expect(AppVersionSettings.compare('1.2.0', '1.4.0'), lessThan(0));
      expect(AppVersionSettings.compare('1.4.0', '1.4.0'), 0);
      expect(AppVersionSettings.compare('1.5.0', '1.4.0'), greaterThan(0));
    });

    test('mengabaikan build number pada versi', () {
      expect(AppVersionSettings.compare('1.4.0+5', '1.4.0'), 0);
    });

    test('menyamakan panjang segmen yang berbeda', () {
      expect(AppVersionSettings.compare('1.4', '1.4.0'), 0);
      expect(AppVersionSettings.compare('1.4', '1.4.1'), lessThan(0));
    });
  });

  group('AppThemeSettings.parseHex', () {
    test('membaca warna 6 digit dengan dan tanpa tanda pagar', () {
      expect(AppThemeSettings.parseHex('#2563eb')?.toARGB32(), 0xff2563eb);
      expect(AppThemeSettings.parseHex('2563eb')?.toARGB32(), 0xff2563eb);
    });

    test('mengembalikan null untuk nilai tidak valid', () {
      expect(AppThemeSettings.parseHex(null), isNull);
      expect(AppThemeSettings.parseHex('bukan-warna'), isNull);
    });
  });

  group('PreCheckRequirements', () {
    test('foto wajib untuk mode jarak jauh saat remote_photo_required', () {
      const req = PreCheckRequirements(
        photoRequired: false,
        remotePhotoRequired: true,
      );
      expect(req.photoRequiredFor(WorkMode.wfo), isFalse);
      expect(req.photoRequiredFor(WorkMode.wfh), isTrue);
      expect(req.photoRequiredFor(WorkMode.wfa), isTrue);
    });

    test('photo_required berlaku untuk semua mode', () {
      const req = PreCheckRequirements(photoRequired: true);
      expect(req.photoRequiredFor(WorkMode.wfo), isTrue);
    });

    test('catatan hanya wajib untuk WFH/WFA', () {
      const req = PreCheckRequirements(remoteNotesRequired: true);
      expect(req.notesRequiredFor(WorkMode.wfo), isFalse);
      expect(req.notesRequiredFor(WorkMode.wfh), isTrue);
    });
  });

  group('AttendancePreCheck', () {
    final json = <String, dynamic>{
      'server_time': '2026-09-01T19:56:27+07:00',
      'date': '2026-09-01',
      'next_action': 'check_in',
      'can_check_in': true,
      'can_check_out': false,
      'blockers': ['Anda sedang dalam masa cuti.'],
      'work_mode': {
        'default': 'wfh',
        'allowed': ['wfo', 'wfh'],
        'requires_location': true,
        'location_ready': true,
      },
      'requirements': {
        'photo_required': false,
        'remote_photo_required': true,
        'remote_notes_required': true,
      },
      'map': {
        'default_zoom': 17,
        'tile_url': 'https://tile.example/{z}/{x}/{y}.png',
        'user_position': {'latitude': -6.2, 'longitude': 106.8},
      },
      'nearest_location': {
        'id': 1,
        'name': 'Kantor Pusat',
        'latitude': -6.2,
        'longitude': 106.8,
        'radius_meters': 500,
        'distance_meters': 120.4,
        'within_radius': true,
      },
      'locations': [
        {
          'id': 1,
          'name': 'Kantor Pusat',
          'latitude': -6.2,
          'longitude': 106.8,
          'radius_meters': 500,
          'within_radius': true,
        }
      ],
    };

    test('memetakan kelayakan dan konfigurasi peta', () {
      final data = AttendancePreCheck.fromMap(json);

      expect(data.nextAction, NextAction.checkIn);
      expect(data.actionEnabled, isTrue);
      expect(data.blockers, hasLength(1));
      expect(data.workMode.allowed, [WorkMode.wfo, WorkMode.wfh]);
      expect(data.map.tileUrl, 'https://tile.example/{z}/{x}/{y}.png');
      expect(data.hasUserPosition, isTrue);
      expect(data.locations, hasLength(1));
    });

    test('memakai mode absen masuk saat giliran absen pulang', () {
      final data = AttendancePreCheck.fromMap({
        ...json,
        'next_action': 'check_out',
        'can_check_out': true,
        'attendance': {'id': 1, 'work_mode': 'wfa'},
      });

      expect(data.effectiveDefaultMode, WorkMode.wfa);
      // Mode terkunci saat absen pulang, jadi tidak ada pilihan ditawarkan.
      expect(data.selectableModes, isEmpty);
      expect(data.actionEnabled, isTrue);
    });

    test('menandai presensi selesai', () {
      final data = AttendancePreCheck.fromMap({
        ...json,
        'next_action': 'done',
        'can_check_in': false,
      });
      expect(data.isDone, isTrue);
      expect(data.actionEnabled, isFalse);
    });
  });

  group('Pemisahan mode kerja per pintu masuk', () {
    // Beranda punya dua pintu: tombol absen kantor dan tombol WFH/WFA.
    // Pemisahannya bertumpu pada WorkMode.isRemote, jadi dikunci di sini.
    test('hanya WFO yang dianggap presensi kantor', () {
      expect(WorkMode.wfo.isRemote, isFalse);
      expect(WorkMode.wfh.isRemote, isTrue);
      expect(WorkMode.wfa.isRemote, isTrue);
    });

    test('menyaring mode yang diizinkan sesuai pintu masuk', () {
      const allowed = [WorkMode.wfo, WorkMode.wfh, WorkMode.wfa];

      final office = allowed.where((m) => !m.isRemote).toList();
      final remote = allowed.where((m) => m.isRemote).toList();

      expect(office, [WorkMode.wfo]);
      expect(remote, [WorkMode.wfh, WorkMode.wfa]);
    });

    test('akun WFO tidak menyisakan pilihan untuk pintu jarak jauh', () {
      const allowed = [WorkMode.wfo];
      expect(allowed.where((m) => m.isRemote), isEmpty);
    });
  });

  group('AttendanceLocation.distanceLabel', () {
    test('memakai meter di bawah 1 km dan kilometer di atasnya', () {
      const near = AttendanceLocation(
        name: 'A',
        latitude: 0,
        longitude: 0,
        radiusMeters: 100,
        distanceMeters: 120.4,
      );
      const far = AttendanceLocation(
        name: 'B',
        latitude: 0,
        longitude: 0,
        radiusMeters: 100,
        distanceMeters: 11793.23,
      );

      expect(near.distanceLabel, '120 m');
      expect(far.distanceLabel, '11,8 km');
    });
  });

  group('Attendance', () {
    test('membaca bukti presensi dari respons baru', () {
      final attendance = Attendance.fromMap({
        'id': 788,
        'date': '2026-09-01',
        'time_in': '08:05',
        'status': 'on_time',
        'status_label': 'Tepat Waktu',
        'work_mode': 'wfh',
        'work_mode_label': 'WFH',
        'is_remote': true,
        'work_duration_minutes': 495,
        'check_in': {
          'latlon': '-6.3,106.9',
          'coordinates': {'latitude': -6.3, 'longitude': 106.9},
          'address': 'Jl. Mawar No. 5, Depok',
          'photo_url': 'https://host/storage/a.jpg',
          'notes': 'Laporan bulanan',
          'distance_meters': 11793,
        },
      });

      expect(attendance.displayStatus, 'Tepat Waktu');
      expect(attendance.displayWorkMode, 'WFH');
      expect(attendance.isRemoteMode, isTrue);
      expect(attendance.workDurationLabel, '8j 15m');
      expect(attendance.checkIn?.hasPhoto, isTrue);
      expect(attendance.checkIn?.latitude, -6.3);
    });

    test('tanggal tidak bergeser walau server mengirim ISO beroffset', () {
      final attendance =
          Attendance.fromMap({'date': '2026-09-01T00:00:00+07:00'});
      expect(attendance.date, DateTime(2026, 9, 1));
    });

    test('memetakan status endpoint lama tanpa status_label', () {
      expect(Attendance.fromMap({'status': 'late'}).displayStatus, 'Terlambat');
    });
  });

  group('AttendanceResponseModel', () {
    test('membaca daftar dan meta paginasi', () {
      final model = AttendanceResponseModel.fromMap({
        'data': [
          {'id': 1, 'date': '2026-09-01'},
          {'id': 2, 'date': '2026-09-02'},
        ],
        'meta': {'current_page': 2, 'last_page': 131, 'total': 262},
      });

      expect(model.data, hasLength(2));
      expect(model.currentPage, 2);
      expect(model.total, 262);
    });

    test('menerima bentuk paginasi Laravel bersarang', () {
      final model = AttendanceResponseModel.fromMap({
        'data': {
          'data': [
            {'id': 1, 'date': '2026-09-01'}
          ]
        }
      });
      expect(model.data, hasLength(1));
    });
  });

  group('AttendanceSummary', () {
    test('menghitung label durasi dan rasio tepat waktu', () {
      final summary = AttendanceSummary.fromMap({
        'year': 2026,
        'month': 9,
        'total_present': 20,
        'on_time': 18,
        'late': 2,
        'late_minutes': 37,
        'work_minutes': 9600,
        'by_work_mode': {'wfo': 15, 'wfh': 5, 'wfa': 0},
        'approved_leave_days': 2,
      });

      expect(summary.workDurationLabel, '160j');
      expect(summary.lateDurationLabel, '37 menit');
      expect(summary.onTimeRatio, closeTo(0.9, 0.001));
      expect(summary.countFor(WorkMode.wfh), 5);
    });
  });

  group('Leave', () {
    test('membaca objek lampiran baru', () {
      final leave = Leave.fromMap({
        'id': 11,
        'status': 'pending',
        'status_label': 'Menunggu',
        'can_cancel': true,
        'attachment': {
          'url': 'https://host/storage/surat.jpg',
          'name': 'surat-dokter.jpg',
          'mime': 'image/jpeg',
          'size': 184320,
        },
      });

      expect(leave.displayStatus, 'Menunggu');
      expect(leave.cancellable, isTrue);
      expect(leave.hasAttachment, isTrue);
      expect(leave.attachment?.sizeLabel, '180 KB');
      expect(leave.attachment?.isPdf, isFalse);
    });

    test('tetap membaca attachment_url dari respons lama', () {
      final leave = Leave.fromMap({
        'id': 1,
        'status': 'approved',
        'attachment_url': 'https://host/storage/berkas.pdf',
      });

      expect(leave.displayStatus, 'Disetujui');
      expect(leave.hasAttachment, isTrue);
      expect(leave.attachment?.isPdf, isTrue);
      // Tanpa can_cancel, hanya pengajuan pending yang boleh dibatalkan.
      expect(leave.cancellable, isFalse);
    });
  });

  group('UserRemoteDatasource.validateNewPassword', () {
    test('menerima password yang memenuhi aturan server', () {
      expect(
        UserRemoteDatasource.validateNewPassword('Rahasia123', 'password'),
        isNull,
      );
    });

    test('menolak password pendek, tanpa angka, atau sama dengan yang lama', () {
      expect(
        UserRemoteDatasource.validateNewPassword('Rah12', 'password'),
        contains('8 karakter'),
      );
      expect(
        UserRemoteDatasource.validateNewPassword('RahasiaSaya', 'password'),
        contains('angka'),
      );
      expect(
        UserRemoteDatasource.validateNewPassword('Rahasia123', 'Rahasia123'),
        contains('berbeda'),
      );
    });
  });
}
