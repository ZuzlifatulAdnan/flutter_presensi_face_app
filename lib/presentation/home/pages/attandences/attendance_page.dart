import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:flutter_absensi_app/core/helper/device_info_helper.dart';
import 'package:flutter_absensi_app/core/helper/location_helper.dart';
import 'package:flutter_absensi_app/core/ml/face_engine_provider.dart';
import 'package:flutter_absensi_app/core/network/api_client.dart';
import 'package:flutter_absensi_app/core/theme/app_theme.dart';
import 'package:flutter_absensi_app/data/models/request/checkinout_request_model.dart';
import 'package:flutter_absensi_app/data/models/response/attendance_precheck_model.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/attendance_precheck/attendance_precheck_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/checkin_attendance/checkin_attendance_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/checkout_attendance/checkout_attendance_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/bloc/is_checkedin/is_checkedin_bloc.dart';
import 'package:flutter_absensi_app/presentation/home/pages/attandences/face_capture_page.dart';
import 'package:flutter_absensi_app/presentation/home/pages/attendance_success_page.dart';
import 'package:flutter_absensi_app/presentation/home/widgets/attendance_map.dart';
import 'package:flutter_absensi_app/presentation/home/widgets/work_mode_selector.dart';

/// Ruang lingkup presensi yang dibuka dari beranda.
///
/// Beranda punya dua pintu masuk terpisah supaya pengguna tidak perlu memilih
/// mode kerja di dalam satu halaman yang sama: tombol absen biasa untuk di
/// kantor, dan tombol WFH/WFA untuk kerja jarak jauh.
enum AttendanceScope {
  /// Presensi dari kantor (WFO) — divalidasi radius lokasi.
  office,

  /// Presensi jarak jauh (WFH/WFA) — tanpa validasi radius, tetapi foto dan
  /// catatan aktivitas biasanya diwajibkan.
  remote;

  bool get isRemote => this == AttendanceScope.remote;

  String get title => switch (this) {
        AttendanceScope.office => 'Presensi Kantor',
        AttendanceScope.remote => 'Presensi WFH/WFA',
      };
}

/// Halaman presensi: peta, kelayakan, mode kerja, bukti foto, dan catatan.
///
/// Seluruh aturan diambil dari `GET /api/attendance/pre-check` — label tombol,
/// aktif/tidaknya tombol, mode kerja yang boleh dipilih, dan wajib-tidaknya
/// foto & catatan. Server tetap memvalidasi ulang saat presensi dikirim.
class AttendancePage extends StatefulWidget {
  /// Membatasi mode kerja yang ditawarkan halaman ini.
  final AttendanceScope scope;

  const AttendancePage({super.key, this.scope = AttendanceScope.office});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final TextEditingController _notesController = TextEditingController();

  UserLocation? _location;
  String? _locationError;
  bool _locatingUser = true;

  WorkMode? _selectedMode;
  Uint8List? _photoBytes;
  String _photoName = 'selfie.jpg';
  bool _faceVerified = false;

  /// Jam server dipakai untuk tampilan waktu — jam perangkat bisa digeser.
  Timer? _clock;
  DateTime? _serverTime;
  DateTime? _serverTimeSyncedAt;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _locate({bool silent = false}) async {
    if (!silent) setState(() => _locatingUser = true);

    try {
      final position = await LocationHelper.current();
      if (!mounted) return;
      setState(() {
        _location = position;
        _locationError = null;
        _locatingUser = false;
      });
      _refreshPreCheck(silent: silent);

      // Alamat menyusul supaya peta tidak menunggu reverse geocoding.
      final address = await LocationHelper.addressOf(
        position.latitude,
        position.longitude,
      );
      if (!mounted || address == null) return;
      setState(() => _location = _location?.copyWithAddress(address));
    } on LocationFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.message;
        _locatingUser = false;
      });
      // Pre-check tetap dipanggil: daftar kantor dikirim walau tanpa koordinat.
      _refreshPreCheck(silent: silent);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Gagal membaca lokasi. Coba lagi.';
        _locatingUser = false;
      });
      _refreshPreCheck(silent: silent);
    }
  }

  void _refreshPreCheck({bool silent = false}) {
    context.read<AttendancePrecheckBloc>().add(
          AttendancePrecheckEvent.fetch(
            latitude: _location?.latitude,
            longitude: _location?.longitude,
            silent: silent,
          ),
        );
  }

  /// Jam berjalan berbasis `server_time`, bukan jam perangkat.
  DateTime get _displayTime {
    final base = _serverTime;
    final syncedAt = _serverTimeSyncedAt;
    if (base == null || syncedAt == null) return DateTime.now();
    return base.add(DateTime.now().difference(syncedAt));
  }

  void _onPreCheckLoaded(AttendancePreCheck data) {
    _serverTime = data.serverTime;
    _serverTimeSyncedAt = data.serverTime == null ? null : DateTime.now();

    // Mode default hanya diterapkan sekali, atau saat pilihan lama tidak lagi
    // sesuai (server mencabut izin WFH, atau halaman dibuka dari pintu lain).
    final allowed = _modesFor(data);
    if (_selectedMode == null || !allowed.contains(_selectedMode)) {
      _selectedMode = allowed.isEmpty ? null : allowed.first;
    }
  }

  /// Mode kerja yang ditawarkan halaman ini.
  ///
  /// Saat absen pulang, mode terkunci ke mode absen masuk sehingga scope
  /// halaman tidak berlaku — server yang menentukan.
  List<WorkMode> _modesFor(AttendancePreCheck data) {
    if (data.nextAction == NextAction.checkOut) return const [];

    final allowed = data.workMode.allowed;
    return allowed
        .where((mode) => mode.isRemote == widget.scope.isRemote)
        .toList();
  }

  WorkMode _modeFor(AttendancePreCheck data) {
    if (data.nextAction == NextAction.checkOut) {
      return data.effectiveDefaultMode;
    }
    final allowed = _modesFor(data);
    final selected = _selectedMode;
    if (selected != null && allowed.contains(selected)) return selected;
    return allowed.isEmpty ? data.effectiveDefaultMode : allowed.first;
  }

  /// Scope ini tidak tersedia untuk akun pengguna.
  bool _scopeUnavailable(AttendancePreCheck data) =>
      data.nextAction != NextAction.checkOut && _modesFor(data).isEmpty;

  Future<void> _capturePhoto(AttendancePreCheck data) async {
    // Verifikasi wajah hanya ditawarkan bila mesin wajah tersedia; di web
    // dan desktop halaman yang sama berubah jadi pengambilan selfie biasa.
    final mode = FaceEngineProvider.isSupported
        ? FaceCaptureMode.verify
        : FaceCaptureMode.photoOnly;

    final result = await Navigator.of(context).push<FaceCaptureResult>(
      MaterialPageRoute(
        builder: (_) => FaceCapturePage(
          mode: mode,
          title: data.nextAction == NextAction.checkOut
              ? 'Foto Absen Pulang'
              : 'Foto Absen Masuk',
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _photoBytes = result.bytes;
      _photoName = result.filename;
      _faceVerified = result.verified;
    });
  }

  /// Cek syarat sebelum request dikirim, supaya pengguna tidak menunggu
  /// respons 422 untuk hal yang bisa diketahui di aplikasi.
  String? _validate(AttendancePreCheck data) {
    final mode = _modeFor(data);

    if (data.requirements.photoRequiredFor(mode) && _photoBytes == null) {
      return data.nextAction == NextAction.checkOut
          ? 'Foto bukti absen pulang wajib dilampirkan.'
          : 'Foto bukti absen masuk wajib dilampirkan.';
    }

    if (data.nextAction == NextAction.checkIn &&
        data.requirements.notesRequiredFor(mode) &&
        _notesController.text.trim().isEmpty) {
      return 'Catatan aktivitas wajib diisi untuk presensi WFH/WFA.';
    }

    if (data.requirements.blockMockLocation && _location?.isMocked == true) {
      return 'Lokasi palsu (fake GPS) terdeteksi. Matikan aplikasi fake GPS '
          'lalu ulangi presensi.';
    }

    if (data.workMode.requiresLocation && !mode.isRemote && _location == null) {
      return _locationError ??
          'Lokasi belum tersedia. Aktifkan GPS lalu coba lagi.';
    }

    return null;
  }

  Future<void> _submit(AttendancePreCheck data) async {
    final error = _validate(data);
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    final mode = _modeFor(data);
    final photo = _photoBytes;

    final request = CheckInOutRequestModel(
      latitude: _location?.latitude.toString(),
      longitude: _location?.longitude.toString(),
      workMode: mode.value,
      notes: _notesController.text,
      address: _location?.address,
      isMockLocation: _location?.isMocked,
      deviceInfo: await DeviceInfoHelper.deviceInfo(),
      accuracy: _location?.accuracy,
      photo: photo == null
          ? null
          : UploadFile.bytes('photo', photo, filename: _photoName),
    );

    if (!mounted) return;
    if (data.nextAction == NextAction.checkOut) {
      context
          .read<CheckoutAttendanceBloc>()
          .add(CheckoutAttendanceEvent.submit(request));
    } else {
      context
          .read<CheckinAttendanceBloc>()
          .add(CheckinAttendanceEvent.submit(request));
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppTheme.danger : AppTheme.success,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _onSubmitted(String message, bool isCheckIn) {
    context.read<IsCheckedinBloc>().add(const IsCheckedinEvent.isCheckedIn());
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AttendanceSuccessPage(
          status: isCheckIn ? 'datang' : 'pulang',
          message: message,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CheckinAttendanceBloc, CheckinAttendanceState>(
          listener: (context, state) => state.mapOrNull<void>(
            loaded: (s) => _onSubmitted(
              s.responseModel.message ?? 'Absen masuk berhasil.',
              true,
            ),
            error: (s) => _onSubmitFailed(s.message),
          ),
        ),
        BlocListener<CheckoutAttendanceBloc, CheckoutAttendanceState>(
          listener: (context, state) => state.mapOrNull<void>(
            loaded: (s) => _onSubmitted(
              s.responseModel.message ?? 'Absen pulang berhasil.',
              false,
            ),
            error: (s) => _onSubmitFailed(s.message),
          ),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: BlocBuilder<AttendancePrecheckBloc, AttendancePrecheckState>(
            builder: (context, state) => Text(
              state.maybeWhen(
                loaded: (data, _) => data.nextAction == NextAction.checkOut
                    ? 'Absen Pulang · ${data.effectiveDefaultMode.label}'
                    : widget.scope.title,
                orElse: () => widget.scope.title,
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Perbarui lokasi',
              onPressed: () => _locate(silent: true),
              icon: const Icon(Icons.my_location_rounded),
            ),
          ],
        ),
        body: BlocConsumer<AttendancePrecheckBloc, AttendancePrecheckState>(
          listener: (context, state) => state.mapOrNull<void>(
            loaded: (s) => _onPreCheckLoaded(s.data),
          ),
          builder: (context, state) => state.when(
            initial: () => const _CenteredLoader(),
            loading: () => const _CenteredLoader(),
            error: (message) => _ErrorState(
              message: message,
              onRetry: () => _locate(),
            ),
            loaded: (data, refreshing) => _buildContent(data, refreshing),
          ),
        ),
      ),
    );
  }

  void _onSubmitFailed(String message) {
    _showMessage(message, isError: true);
    // 409 (sudah absen / sedang cuti) mengubah keadaan di server, jadi
    // kelayakan presensi perlu dibaca ulang.
    _refreshPreCheck(silent: true);
  }

  Widget _buildContent(AttendancePreCheck data, bool refreshing) {
    return Stack(
      children: [
        AttendanceMap(
          data: data,
          userLatitude: _location?.latitude,
          userLongitude: _location?.longitude,
        ),
        if (refreshing || _locatingUser)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: _RefreshPill()),
          ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: _ClockCard(time: _displayTime, shift: data.shift),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.46,
          minChildSize: 0.30,
          maxChildSize: 0.92,
          builder: (context, scrollController) => _AttendanceSheet(
            data: data,
            scope: widget.scope,
            availableModes: _modesFor(data),
            scopeUnavailable: _scopeUnavailable(data),
            scrollController: scrollController,
            location: _location,
            locationError: _locationError,
            selectedMode: _modeFor(data),
            onModeChanged: (mode) => setState(() => _selectedMode = mode),
            notesController: _notesController,
            photoBytes: _photoBytes,
            faceVerified: _faceVerified,
            onCapturePhoto: () => _capturePhoto(data),
            onRemovePhoto: () => setState(() {
              _photoBytes = null;
              _faceVerified = false;
            }),
            onSubmit: () => _submit(data),
          ),
        ),
      ],
    );
  }
}

/// Isi sheet: status, jarak, blocker, mode kerja, bukti foto, catatan, tombol.
class _AttendanceSheet extends StatelessWidget {
  final AttendancePreCheck data;
  final AttendanceScope scope;
  final List<WorkMode> availableModes;
  final bool scopeUnavailable;
  final ScrollController scrollController;
  final UserLocation? location;
  final String? locationError;
  final WorkMode selectedMode;
  final ValueChanged<WorkMode> onModeChanged;
  final TextEditingController notesController;
  final Uint8List? photoBytes;
  final bool faceVerified;
  final VoidCallback onCapturePhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onSubmit;

  const _AttendanceSheet({
    required this.data,
    required this.scope,
    required this.availableModes,
    required this.scopeUnavailable,
    required this.scrollController,
    required this.location,
    required this.locationError,
    required this.selectedMode,
    required this.onModeChanged,
    required this.notesController,
    required this.photoBytes,
    required this.faceVerified,
    required this.onCapturePhoto,
    required this.onRemovePhoto,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final photoRequired = data.requirements.photoRequiredFor(selectedMode);
    final notesRequired = data.nextAction == NextAction.checkIn &&
        data.requirements.notesRequiredFor(selectedMode);
    final modes = availableModes;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -6)),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),

          if (scopeUnavailable)
            const _Notice(
              icon: Icons.lock_outline_rounded,
              color: AppTheme.danger,
              message: 'Akun Anda belum diizinkan melakukan presensi jarak '
                  'jauh. Gunakan menu presensi kantor, atau hubungi admin '
                  'untuk mengubah mode kerja Anda.',
            )
          else if (scope.isRemote)
            const _RemoteInfoTile()
          else
            _NearestLocationTile(data: data),
          const SizedBox(height: 12),

          if (location != null)
            _MetaRow(
              icon: Icons.gps_fixed_rounded,
              label: 'Akurasi GPS',
              value: location!.accuracyLabel,
              warning: !location!.isAccurateEnough(
                data.requirements.accuracyToleranceMeters,
              ),
            ),
          if (location?.address != null)
            _MetaRow(
              icon: Icons.place_outlined,
              label: 'Alamat',
              value: location!.address!,
            ),
          if (locationError != null)
            _Notice(
              icon: Icons.location_off_rounded,
              color: AppTheme.warning,
              message: locationError!,
            ),
          if (location?.isMocked == true)
            const _Notice(
              icon: Icons.gpp_bad_rounded,
              color: AppTheme.danger,
              message: 'Lokasi palsu (fake GPS) terdeteksi. Matikan aplikasi '
                  'fake GPS sebelum melakukan presensi.',
            ),

          for (final blocker in data.blockers)
            _Notice(
              icon: Icons.info_outline_rounded,
              color: AppTheme.warning,
              message: blocker,
            ),

          if (modes.length > 1) ...[
            const SizedBox(height: 20),
            _SectionTitle(
              scope.isRemote ? 'Jenis Kerja Jarak Jauh' : 'Mode Kerja',
            ),
            const SizedBox(height: 10),
            WorkModeSelector(
              modes: modes,
              selected: selectedMode,
              onChanged: onModeChanged,
            ),
          ],

          if (photoRequired || photoBytes != null) ...[
            const SizedBox(height: 20),
            _SectionTitle(
              'Foto Bukti',
              required: photoRequired,
            ),
            const SizedBox(height: 10),
            _PhotoField(
              bytes: photoBytes,
              verified: faceVerified,
              onCapture: onCapturePhoto,
              onRemove: onRemovePhoto,
            ),
          ],

          if (notesRequired || selectedMode.isRemote) ...[
            const SizedBox(height: 20),
            _SectionTitle('Catatan Aktivitas', required: notesRequired),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Contoh: Mengerjakan laporan bulanan dari rumah',
                counterText: '',
              ),
            ),
          ],

          const SizedBox(height: 24),
          _ActionButton(
            data: data,
            enabled: !scopeUnavailable,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final AttendancePreCheck data;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.data,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final submitting = context.select<CheckinAttendanceBloc, bool>(
          (bloc) => bloc.state.maybeWhen(loading: () => true, orElse: () => false),
        ) ||
        context.select<CheckoutAttendanceBloc, bool>(
          (bloc) => bloc.state.maybeWhen(loading: () => true, orElse: () => false),
        );

    final canSubmit = enabled && data.actionEnabled && !submitting;

    return Column(
      children: [
        FilledButton.icon(
          onPressed: canSubmit ? onPressed : null,
          icon: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  data.nextAction == NextAction.checkOut
                      ? Icons.logout_rounded
                      : Icons.login_rounded,
                ),
          label: Text(submitting ? 'Mengirim...' : data.nextAction.label),
        ),
        if (data.isDone)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Presensi hari ini sudah lengkap. Sampai jumpa besok!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// Penjelas untuk presensi jarak jauh.
///
/// Radius kantor tidak divalidasi pada WFH/WFA, jadi indikator merah/hijau
/// dari [_NearestLocationTile] justru menyesatkan di sini.
class _RemoteInfoTile extends StatelessWidget {
  const _RemoteInfoTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.home_work_rounded, color: AppTheme.info),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Presensi Jarak Jauh',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2),
                Text(
                  'Tidak divalidasi radius kantor. Lokasi, foto, dan catatan '
                  'aktivitas Anda tetap dicatat sebagai bukti.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.info,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearestLocationTile extends StatelessWidget {
  final AttendancePreCheck data;

  const _NearestLocationTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final nearest = data.nearestLocation;
    if (nearest == null) {
      return const _Notice(
        icon: Icons.domain_disabled_rounded,
        color: AppTheme.warning,
        message: 'Belum ada lokasi kantor aktif yang dikonfigurasi. '
            'Hubungi admin.',
      );
    }

    final inside = nearest.withinRadius;
    final color = inside ? AppTheme.success : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            inside ? Icons.where_to_vote_rounded : Icons.wrong_location_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nearest.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  inside
                      ? 'Anda berada di dalam radius kantor '
                          '(${nearest.distanceLabel})'
                      : 'Jarak ke kantor: ${nearest.distanceLabel} '
                          '— radius ${nearest.radiusMeters.round()} m',
                  style: TextStyle(fontSize: 12.5, color: color, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  final Uint8List? bytes;
  final bool verified;
  final VoidCallback onCapture;
  final VoidCallback onRemove;

  const _PhotoField({
    required this.bytes,
    required this.verified,
    required this.onCapture,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return OutlinedButton.icon(
        onPressed: onCapture,
        icon: const Icon(Icons.camera_alt_rounded),
        label: Text(
          FaceEngineProvider.isSupported
              ? 'Ambil Foto & Verifikasi Wajah'
              : 'Ambil Foto Selfie',
        ),
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Image.memory(
            bytes!,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    verified
                        ? Icons.verified_rounded
                        : Icons.photo_camera_back_rounded,
                    size: 18,
                    color: verified ? AppTheme.success : AppTheme.info,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    verified ? 'Wajah terverifikasi' : 'Foto siap dikirim',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: verified ? AppTheme.success : AppTheme.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: onCapture,
                    child: const Text('Ambil Ulang'),
                  ),
                  TextButton(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                    ),
                    child: const Text('Hapus'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClockCard extends StatelessWidget {
  final DateTime time;
  final PreCheckShift? shift;

  const _ClockCard({required this.time, required this.shift});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('HH:mm:ss').format(time),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(time),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (shift != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    shift!.name ?? 'Shift',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    shift!.range,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool required;

  const _SectionTitle(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (required)
          const Text(' *', style: TextStyle(color: AppTheme.danger)),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppTheme.warning : AppTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12.5, color: color),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: warning ? AppTheme.warning : AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _Notice({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshPill extends StatelessWidget {
  const _RefreshPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Memperbarui lokasi...',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
